<script lang="ts">
	import type { GridType } from '@prisma/client';
	import SvgHexagon from './SvgHexagon.svelte';

	export let id: string;
	export let gridType: GridType;

	export let cellWidth: number;
	export let cellHeight: number;
</script>

{#if gridType === 'SQUARE'}
	<pattern {id} patternUnits="userSpaceOnUse" width="{cellWidth}px" height="{cellHeight}px">
		<rect width="100%" height="100%" />
	</pattern>
{:else if gridType === 'HEX_HORIZONTAL'}
	<pattern {id} patternUnits="userSpaceOnUse" width="{cellWidth * 2}px" height="{cellHeight}px">
		<SvgHexagon offset={{ x: 0.5, y: 0.5 }} {cellWidth} />
		<SvgHexagon offset={{ x: 1.5, y: 0 }} {cellWidth} />
		<SvgHexagon offset={{ x: 1.5, y: 1 }} {cellWidth} />
	</pattern>
{/if}
