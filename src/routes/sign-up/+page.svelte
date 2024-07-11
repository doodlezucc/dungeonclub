<script lang="ts">
	import { fly } from 'svelte/transition';
	import ConfirmPasswordPage from '../home/ConfirmPasswordPage.svelte';

	$: errorReason = '';

	$: emailAddress = '';
	$: password = '';
	$: passwordConfirmation = '';

	$: {
		if (emailAddress && password) {
			errorReason = '';
		}
	}
</script>

<ConfirmPasswordPage
	title="Create a new Account"
	submitButtonLabel="Sign Up"
	bind:emailAddress
	bind:password
	bind:passwordConfirmation
	bind:errorReason
>
	<span slot="note" class="note" in:fly={{ delay: 100, y: 20, duration: 600 }}>
		Tip! Accounts are <em>not required</em><br />
		for players, only for game leaders.
	</span>

	<span slot="links">
		Already have an account?<br />
		<a href="/">Log in here</a>
	</span>
</ConfirmPasswordPage>

<style>
	span {
		text-align: center;
	}

	.note {
		margin-top: 0.5em;
		color: var(--color-text-pale);
	}
</style>
