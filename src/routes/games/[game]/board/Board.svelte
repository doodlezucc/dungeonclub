<script lang="ts" context="module">
	export interface BoardContext {
		dimensions: Size;
		cellSize: number;
	}
</script>

<script lang="ts">
	import { board } from '$lib/client/state/board';
	import type { Position, Size } from '$lib/compounds';
	import { PanView } from 'components';
	import { Overlay } from 'components/layout';
	import { setContext } from 'svelte';
	import BattleMap from './BattleMap.svelte';
	import Grid from './Grid.svelte';
	import Token from './grid/Token.svelte';

	const cellsPerRow = $board!.grid.cellsPerRow;

	let position: Position = { x: 0, y: 0 };
	let zoom: number = 0;

	$: dimensions = undefined as Size | undefined;

	$: cellSize = (dimensions?.width ?? 0) / cellsPerRow;

	if (dimensions) {
		setContext('board', <BoardContext>{
			cellSize: dimensions.width / cellsPerRow
		});
	}
</script>

<PanView expand bind:position bind:zoom>
	<div class="board" style="--cell-size: {cellSize}px">
		<BattleMap bind:size={dimensions} />

		{#if dimensions}
			<Overlay>
				<Grid {dimensions} {cellsPerRow} />
			</Overlay>

			<Overlay>
				<Token position={{ x: 1.5, y: 1.5 }}></Token>
				<Token size={2} position={{ x: 4, y: 1 }}></Token>
			</Overlay>
		{/if}
	</div>
</PanView>

<style>
	.board {
		position: relative;
		display: flex;
		align-self: center;
	}
</style>
