<script lang="ts">
	import { getContext } from 'svelte';

	const { cellsPerRow, dimensions } = getContext('board');

	$: cellSize = dimensions.width / cellsPerRow;
	$: numberOfRows = Math.floor(dimensions.height / cellSize);
</script>

<svg width={dimensions.width} height={dimensions.height}>
	{#each { length: cellsPerRow + 1 } as _, i}
		<line x1={i * cellSize} x2={i * cellSize} y1={0} y2="100%"></line>
	{/each}
	{#each { length: numberOfRows + 1 } as _, i}
		<line x1={0} x2="100%" y1={i * cellSize} y2={i * cellSize}></line>
	{/each}
</svg>

<style>
	line {
		stroke-width: 1px;
		stroke: white;
	}
</style>
