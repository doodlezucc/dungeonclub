<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();
</script>

<div>
	{@render children()}
</div>

<style>
	div {
		margin: 0 auto;
		width: calc(100vw - 5em);
		max-width: calc(60vw + 20em);
	}
</style>
