<script lang="ts">
	import { RequestError } from '$lib/net';
	import { socket } from '$lib/stores';
	import { Button, Input } from 'components';
	import { Column, Container } from 'components/layout';
	import { fly } from 'svelte/transition';

	$: emailAddress = '';
	$: password = '';

	$: errorReason = '';
	$: errorKey = 0;

	$: {
		if (emailAddress && password) {
			errorReason = '';
		}
	}

	async function login() {
		try {
			const response = await $socket.logIn(emailAddress, password);

			console.log('Logged in, response:', response);
		} catch (err) {
			if (!(err instanceof RequestError)) throw err;

			errorReason = `${err.message}`;
			errorKey++;
		}
	}
</script>

<Container margin="big" padding="big">
	<Column align="center">
		<h2 aria-label="">Sign in to Dungeon Club</h2>

		<form action="javascript:void(0);" on:submit={() => false}>
			<Input
				label="Email Address"
				placeholder="Email..."
				name="email"
				type="email"
				autocomplete="email"
				bind:value={emailAddress}
			/>
			<Input
				label="Password"
				placeholder="Password..."
				name="password"
				type="password"
				autocomplete="current-password"
				bind:value={password}
			/>

			{#key errorKey}
				<span class="error" aria-live="polite" in:fly={{ y: 20 }}>{errorReason}</span>
			{/key}

			<Button type="submit" on:click={login} raised>Log In</Button>
		</form>
	</Column>
</Container>

<style>
	h2 {
		color: var(--color-primary);
		margin: 0 0 1.5em 0;
	}

	form {
		display: grid;
		gap: 1.5em;
		max-width: 500px;
	}

	.error {
		color: var(--color-bad);
	}
</style>
