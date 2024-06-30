<script lang="ts">
	import { setContext } from 'svelte';

	import { session } from '$lib/client/communication';
	import type { Position, Size } from '$lib/compounds';
	import { PanView } from 'components';
	import { Overlay } from 'components/layout';
	import BattleMap from './BattleMap.svelte';
	import Grid from './Grid.svelte';
	import Token from './grid/Token.svelte';

	const board = $session!.visibleBoard!;

	const cellsPerRow = board.gridCellsPerRow;

	let position: Position = { x: 0, y: 0 };
	let zoom: number = 0;

	const dimensions: Size = { width: 600, height: 400 };

	$: cellSize = dimensions.width / cellsPerRow;

	setContext('board', {
		position,
		zoom,
		dimensions,
		cellsPerRow
	});
</script>

<PanView expand bind:position bind:zoom>
	<div class="board" style="--cell-size: {cellSize}px">
		<BattleMap size={dimensions} />

		<Overlay>
			<Grid />
		</Overlay>

		<Overlay>
			<Token position={{ x: 1.5, y: 1.5 }}></Token>
			<Token size={2} position={{ x: 4, y: 1 }}></Token>
		</Overlay>
	</div>
</PanView>

<style>
	.board {
		position: relative;
		display: flex;
		align-self: center;
	}
</style>
