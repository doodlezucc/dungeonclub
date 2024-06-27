<script>
	import { ClientSocket } from '$lib/client/socket';

	import Content from '$lib/kit/Content.svelte';
	import { onMount } from 'svelte';

	async function connectWebSocket() {
		console.log('connecting websocket');

		const clientSocket = new ClientSocket();
		const response = await clientSocket.request('login', {
			email: 'example@email.co',
			password: 'mypassword'
		});

		console.log('received response', response);
	}

	onMount(() => {
		connectWebSocket();
	});
</script>

<Content>
	<h1>Test Area</h1>
</Content>
