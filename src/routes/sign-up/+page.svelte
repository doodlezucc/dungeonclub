<script lang="ts">
	import { goto } from '$app/navigation';
	import { Account } from 'client/state';
	import { fly } from 'svelte/transition';
	import ActivationCodeForm from '../home/forms/ActivationCodeForm.svelte';
	import ConfirmPasswordPage from '../home/forms/ConfirmPasswordPage.svelte';
	import CredentialsForm from '../home/forms/CredentialsForm.svelte';

	let showActivationCodeForm = $state(false);
	

	async function attemptSignUp(emailAddress: string, password: string) {
		await Account.attemptSignUp(emailAddress, password);
		showActivationCodeForm = true;
	}

	async function attemptVerify(code: string) {
		await Account.verifyActivationCode(`/activate?code=${code}`);
		goto('/');
	}
</script>

<ConfirmPasswordPage {showActivationCodeForm}>
	<!-- @migration-task: migrate this slot by hand, `credentials-form` is an invalid identifier -->
	<svelte:fragment slot="credentials-form">
		<CredentialsForm
			title="Create a new Account"
			submitButtonLabel="Sign Up"
			handleSubmit={attemptSignUp}
		>
			{#snippet note()}
						<span  class="heads-up" in:fly={{ delay: 100, y: 20, duration: 600 }}>
					<b>Tip!</b> Accounts are <em>not required</em><br />
					for players, only for game leaders.
				</span>
					{/snippet}

			{#snippet links()}
						<span >
					Already have an account?<br />
					<a href="/">Log in here</a>
				</span>
					{/snippet}
		</CredentialsForm>
	</svelte:fragment>

	<!-- @migration-task: migrate this slot by hand, `code-form` is an invalid identifier -->
	<svelte:fragment slot="code-form">
		<ActivationCodeForm title="Activate Account" handleCodeSubmit={attemptVerify}>
			{#snippet note()}
						<span >
					Hey there, thanks for signing up. Glad to have you! Please <b>check your email inbox</b> for
					an activation code.
				</span>
					{/snippet}
		</ActivationCodeForm>
	</svelte:fragment>
</ConfirmPasswordPage>

<style>
	.heads-up {
		margin-top: 1em;
		color: var(--color-text-pale);
		text-align: center;
	}

	b {
		color: var(--color-text);
	}
</style>
