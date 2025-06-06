<script lang="ts">
	import Container from 'packages/ui/layout/Container.svelte';
	import type { Snippet } from 'svelte';

	interface Props {
		title: string;
		children: Snippet;
	}

	let { title, children }: Props = $props();
</script>

<Container>
	<h3>{title}</h3>

	{@render children()}
</Container>

<style>
	h3 {
		margin-bottom: 0.5em;
	}
</style>
