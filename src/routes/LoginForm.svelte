<script>
	import Button from '$lib/kit/Button.svelte';
	import Input from '$lib/kit/Input.svelte';
	import Column from '$lib/kit/layout/Column.svelte';
	import { socket } from '$lib/stores';

	$: emailAddress = '';
	$: password = '';

	async function login() {
		const response = await $socket.request('login', {
			email: emailAddress,
			password: password
		});

		console.log('Logged in, your campaigns:', response);
	}
</script>

<Column align="center">
	<h2>Log In</h2>

	<form on:submit={() => false}>
		<Input label="Email" name="email" type="email" autocomplete="email" bind:value={emailAddress} />
		<Input
			label="Password"
			name="password"
			type="password"
			autocomplete="current-password"
			bind:value={password}
		/>

		<Button type="submit" on:click={login} raised>Log In</Button>
	</form>
</Column>

<style>
	form {
		display: grid;
		gap: 2em;
		max-width: 500px;
	}
</style>
