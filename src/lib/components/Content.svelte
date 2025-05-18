<script>
	/** @type {{children?: import('svelte').Snippet}} */
	let { children } = $props();
</script>

<div>
	{@render children?.()}
</div>

<style>
	div {
		margin: 0 auto;
		width: calc(100vw - 5em);
		max-width: calc(60vw + 20em);
	}
</style>
