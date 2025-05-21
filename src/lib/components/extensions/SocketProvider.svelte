<script lang="ts">
	import { browser } from '$app/environment';
	import { ClientSocket } from 'client/communication';
	import type { Snippet } from 'svelte';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();

	if (browser) {
		new ClientSocket();
	}
</script>

{@render children()}
