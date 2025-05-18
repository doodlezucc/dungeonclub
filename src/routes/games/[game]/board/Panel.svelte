<script lang="ts">
	import Container from 'components/layout/Container.svelte';

	interface Props {
		title: string;
		children?: import('svelte').Snippet;
	}

	let { title, children }: Props = $props();
</script>

<Container>
	<h3>{title}</h3>

	{@render children?.()}
</Container>

<style>
	h3 {
		margin-bottom: 0.5em;
	}
</style>
