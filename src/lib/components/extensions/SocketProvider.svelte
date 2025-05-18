<script lang="ts">
	import { browser } from '$app/environment';
	import { ClientSocket } from 'client/communication';
	interface Props {
		children?: import('svelte').Snippet;
	}

	let { children }: Props = $props();

	if (browser) {
		new ClientSocket();
	}
</script>

{@render children?.()}
