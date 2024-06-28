<script lang="ts">
	import { browser } from '$app/environment';
	import { ClientSocket } from '$lib/client/socket';
	import { socket } from '$lib/stores';

	if (browser) {
		socket.update((socket) => {
			if (socket) return socket;

			return new ClientSocket();
		});
	}
</script>

<slot />
