<script lang="ts">
	import { Account } from 'client/state';
	import { Input } from 'components';
	import Dot from 'components/layout/Dot.svelte';
	import { RequestError } from 'shared';
	import Form from './Form.svelte';

	$: errorReason = '';

	$: emailAddress = '';
	$: password = '';

	$: {
		if (emailAddress && password) {
			errorReason = '';
		}
	}

	async function login() {
		try {
			await Account.logIn(emailAddress, password);

			console.log('Logged in');
		} catch (err) {
			if (!(err instanceof RequestError)) throw err;

			errorReason = `${err.message}`;
		}
	}
</script>

<Form title="Sign in to Dungeon Club" submitButtonLabel="Log In" {errorReason} on:submit={login}>
	<Input
		required
		label="Email Address"
		placeholder="Email of your account..."
		name="email"
		type="email"
		autocomplete="email"
		bind:value={emailAddress}
	/>
	<Input
		required
		label="Password"
		placeholder="Password..."
		name="password"
		type="password"
		autocomplete="current-password"
		bind:value={password}
	/>

	<span slot="links">
		<a href="./reset-password">Reset password</a>
		<Dot />
		<a href="./sign-up">Create an account</a>
	</span>
</Form>

<style>
	span {
		text-align: center;
	}
</style>
