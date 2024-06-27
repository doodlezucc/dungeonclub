<script lang="ts">
	import { ClientSocket } from '$lib/client/socket';
	import { socket } from '$lib/stores';
	import { onMount } from 'svelte';

	onMount(() => {
		socket.update((socket) => {
			if (socket) return socket;

			return new ClientSocket();
		});
	});
</script>

<slot />
