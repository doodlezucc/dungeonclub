<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		expand?: boolean;
		children: Snippet;
	}

	let { expand = false, children }: Props = $props();
</script>

<div class:expand>
	{@render children()}
</div>

<style>
	div {
		position: relative;
		display: flex;

		justify-content: center;
	}
</style>
