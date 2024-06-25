<script lang="ts">
	import type { ICampaign } from '$lib/db/schemas/campaign';
	import Overlay from '$lib/kit/layout/Overlay.svelte';
	import PanView, { type Dimensions, type Position } from '$lib/kit/PanView.svelte';
	import { getContext, setContext } from 'svelte';
	import BattleMap from './BattleMap.svelte';
	import Grid from './Grid.svelte';
	import Token from './grid/Token.svelte';

	const session = getContext('session');
	const campaign: ICampaign = session.campaign;

	const scene = campaign.scenes[0];
	const grid = scene.grid;
	const cellsPerRow = grid.cellsPerRow;

	let position: Position;
	let zoom: number;

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
