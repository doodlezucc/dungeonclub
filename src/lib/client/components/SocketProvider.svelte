<script lang="ts">
	import { browser } from '$app/environment';
	import { ClientSocket, socket } from '$lib/client/communication';

	if (browser) {
		socket.update((socket) => {
			if (socket) return socket;

			return new ClientSocket();
		});
	}
</script>

<slot />
