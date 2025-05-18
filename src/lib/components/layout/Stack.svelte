<script>
	/** @type {{expand?: boolean, children?: import('svelte').Snippet}} */
	let { expand = false, children } = $props();
</script>

<div class:expand>
	{@render children?.()}
</div>

<style>
	div {
		position: relative;
		display: flex;

		justify-content: center;
	}
</style>
