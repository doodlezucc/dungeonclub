<script lang="ts">
	import { Account } from 'client/state';
	import { Input } from 'components';
	import Dot from 'components/layout/Dot.svelte';
	import Form from './Form.svelte';

	$: emailAddress = '';
	$: password = '';

	async function attemptLogin() {
		await Account.logIn(emailAddress, password);
	}
</script>

<Form title="Sign in to Dungeon Club" submitButtonLabel="Log In" handleSubmit={attemptLogin}>
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
