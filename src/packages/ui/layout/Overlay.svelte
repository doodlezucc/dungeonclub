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
		position: absolute;
		display: flex;
		left: 0;
		top: 0;
		right: 0;
		bottom: 0;
	}
</style>
