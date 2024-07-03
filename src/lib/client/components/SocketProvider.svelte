<script lang="ts">
	import { browser } from '$app/environment';
	import { ClientSocket } from '$lib/client/communication';

	if (browser) {
		new ClientSocket();
	}
</script>

<slot />
