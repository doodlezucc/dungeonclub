<script>
	import { PUBLIC_WEBSOCKET_URL } from '$env/static/public';

	import Content from '$lib/kit/Content.svelte';
	import { onMount } from 'svelte';

	function connectWebSocket() {
		console.log('connecting websocket');

		const ws = new WebSocket(PUBLIC_WEBSOCKET_URL);
		ws.addEventListener('open', (ev) => {
			console.log('Connection opened!');

			ws.send('hello world');
		});
		ws.addEventListener('message', (ev) => {
			console.log('Message received!', ev.data);
		});
		ws.addEventListener('error', (ev) => {
			console.error('WebSocket error!', ev);
		});
		ws.addEventListener('close', (ev) => {
			console.log('Connection closed!', ev);
		});
	}

	onMount(() => {
		connectWebSocket();
	});
</script>

<Content>
	<h1>Test Area</h1>
</Content>
