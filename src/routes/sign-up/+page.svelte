<script lang="ts">
	import { goto } from '$app/navigation';
	import { Account } from 'client/state';
	import { RequestError } from 'shared';
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

	async function createAccount() {
		try {
			await Account.register(emailAddress, password);

			console.log('Registered + logged in');
			goto('/');
		} catch (err) {
			if (!(err instanceof RequestError)) throw err;

			errorReason = `${err.message}`;
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
	on:submit={createAccount}
>
	<span slot="note" class="note" in:fly={{ delay: 100, y: 20, duration: 600 }}>
		<b>Tip!</b> Accounts are <em>not required</em><br />
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
		margin-top: 1em;
		color: var(--color-text-pale);
	}
</style>
