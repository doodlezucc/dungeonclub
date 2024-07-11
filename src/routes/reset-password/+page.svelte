<script lang="ts">
	import ConfirmPasswordPage from '../home/ConfirmPasswordPage.svelte';

	$: emailAddress = '';
	$: password = '';
	$: passwordConfirmation = '';

	$: errorReason = '';

	$: {
		if (emailAddress && password && passwordConfirmation) {
			errorReason = '';
		}
	}
</script>

<ConfirmPasswordPage
	title="Reset your Password"
	submitButtonLabel="Reset Password"
	bind:emailAddress
	bind:password
	bind:passwordConfirmation
	bind:errorReason
>
	<span slot="links">
		No need to reset?<br />
		<a href="/">Log in here</a>
	</span>
</ConfirmPasswordPage>

<style>
	span {
		text-align: center;
	}
</style>
