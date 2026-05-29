<script lang="ts">
	import { Board } from '$lib/client/state';
	import type { Size } from 'packages/math';
	import GridPattern from './GridPattern.svelte';

	interface Props {
		dimensions: Size;
		cellsPerRow: number;
	}

	let { dimensions, cellsPerRow }: Props = $props();

	const activeGridSpace = Board.instance.grid.gridSpace;

	let cellWidth = $derived(dimensions.width / cellsPerRow);
</script>

<svg id="grid" width={dimensions.width} height={dimensions.height}>
	<defs>
		<GridPattern id="patternSquare" gridSpace={$activeGridSpace} {cellWidth} />
	</defs>

	<rect width="100%" height="100%" fill="url(#patternSquare)" />
</svg>

<style>
	:global(#grid pattern *) {
		stroke-width: 1px;
		stroke: white;
		fill: none;
	}
</style>
