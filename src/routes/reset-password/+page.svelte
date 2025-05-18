<script lang="ts">
	import { goto } from '$app/navigation';
	import { Account } from 'client/state';
	import ActivationCodeForm from '../home/forms/ActivationCodeForm.svelte';
	import ConfirmPasswordPage from '../home/forms/ConfirmPasswordPage.svelte';
	import CredentialsForm from '../home/forms/CredentialsForm.svelte';

	let showActivationCodeForm = $state(false);
	

	async function attemptResetPassword(emailAddress: string, password: string) {
		await Account.attemptResetPassword(emailAddress, password);
		showActivationCodeForm = true;
	}

	async function attemptVerify(code: string) {
		await Account.verifyActivationCode(`/verify-new-password?code=${code}`);
		goto('/');
	}
</script>

<ConfirmPasswordPage {showActivationCodeForm}>
	<!-- @migration-task: migrate this slot by hand, `credentials-form` is an invalid identifier -->
	<svelte:fragment slot="credentials-form">
		<CredentialsForm
			title="Reset your Password"
			passwordInputLabel="New Password"
			submitButtonLabel="Reset Password"
			handleSubmit={attemptResetPassword}
		>
			{#snippet links()}
						<span >
					No need to reset?<br />
					<a href="/">Log in here</a>
				</span>
					{/snippet}
		</CredentialsForm>
	</svelte:fragment>

	<!-- @migration-task: migrate this slot by hand, `code-form` is an invalid identifier -->
	<svelte:fragment slot="code-form">
		<ActivationCodeForm title="Activate New Password" handleCodeSubmit={attemptVerify}>
			{#snippet note()}
						<span >
					To fulfill the request to reset your password, please <b>check your email inbox</b> for an activation
					code.
				</span>
					{/snippet}
		</ActivationCodeForm>
	</svelte:fragment>
</ConfirmPasswordPage>

<style>
	b {
		color: var(--color-text);
	}
</style>
