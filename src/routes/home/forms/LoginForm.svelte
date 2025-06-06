<script lang="ts">
	import { Account } from 'client/state';
	import { Input } from 'packages/ui';
	import Dot from 'packages/ui/layout/Dot.svelte';
	import { enteredEmailAddress } from '../credential-stores';
	import Form from './Form.svelte';

	let password = $state('');

	async function attemptLogin() {
		await Account.logIn($enteredEmailAddress, password);
	}
</script>

<Form title="Sign in to Dungeon Club" submitButtonLabel="Log In" handleSubmit={attemptLogin}>
	<Input
		autofocus
		required
		label="Email Address"
		placeholder="Email of your account..."
		name="email"
		type="email"
		autocomplete="email"
		bind:value={$enteredEmailAddress}
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

	{#snippet links()}
		<span>
			<a href="./reset-password">Reset password</a>
			<Dot />
			<a href="./sign-up">Create an account</a>
		</span>
	{/snippet}
</Form>
