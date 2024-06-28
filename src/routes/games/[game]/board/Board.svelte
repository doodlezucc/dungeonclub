<script lang="ts">
	import Overlay from '$lib/kit/layout/Overlay.svelte';
	import PanView, { type Dimensions, type Position } from '$lib/kit/PanView.svelte';

	import { setContext } from 'svelte';

	import { session } from '$lib/client/socket';
	import BattleMap from './BattleMap.svelte';
	import Grid from './Grid.svelte';
	import Token from './grid/Token.svelte';

	const board = $session!.visibleBoard!;

	const grid = board.grid;
	const cellsPerRow = grid.cellsPerRow;

	let position: Position = { x: 0, y: 0 };
	let zoom: number = 0;

	const dimensions: Dimensions = { width: 600, height: 400 };

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
		<BattleMap {dimensions} />

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
