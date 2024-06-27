<script lang="ts">
	import Button from '$lib/kit/Button.svelte';
	import Content from '$lib/kit/Content.svelte';
	import { socket } from '$lib/stores';
</script>

<Content>
	<h1>Test Area</h1>

	<Button
		on:click={() =>
			$socket.request('accountCreate', {
				email: 'newaccount@email.com',
				password: 'newpassword'
			})}
	>
		Create Account</Button
	>

	<Button
		on:click={() =>
			$socket.request('login', {
				email: 'newaccount@email.com',
				password: 'newpassword'
			})}
	>
		Login
	</Button>
</Content>
