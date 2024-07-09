<script lang="ts" context="module">
	export interface BoardContext {
		transformClientToGridSpace: (position: Position) => Position;
		transformGridToClientSpace: (position: Position) => Position;
	}
</script>

<script lang="ts">
	import type { Position, Size } from '$lib/compounds';
	import { boardState } from 'client/state/board';
	import { PanView } from 'components';
	import { Overlay } from 'components/layout';
	import { setContext } from 'svelte';
	import BattleMap from './BattleMap.svelte';
	import Grid from './Grid.svelte';
	import Token from './grid/Token.svelte';

	const cellsPerRow = $boardState!.gridCellsPerRow;

	$: position = <Position>{ x: 0, y: 0 };
	$: zoom = 0;

	$: dimensions = undefined as Size | undefined;

	$: cellSize = (dimensions?.width ?? 0) / cellsPerRow;

	$: tokens = $boardState!.tokens;

	let contentElement: HTMLElement;
	$: cachedClientRect = undefined as DOMRect | undefined;

	$: {
		// Clear cached client rect when position or zoom change
		if (position && zoom != undefined) {
			cachedClientRect = undefined;
		}
	}

	function getClientRect() {
		return (cachedClientRect ??= contentElement.getBoundingClientRect());
	}

	function transformClientToGridSpace(clientPosition: Position): Position {
		const rect = getClientRect();

		const zoomFactor = Math.exp(zoom);
		const factor = zoomFactor * cellSize;

		return {
			x: (clientPosition.x - rect.x) / factor,
			y: (clientPosition.y - rect.y) / factor
		};
	}

	function transformGridToClientSpace(position: Position): Position {
		throw 'Not implemented';
	}

	setContext('board', <BoardContext>{
		transformClientToGridSpace,
		transformGridToClientSpace
	});
</script>

<PanView expand bind:position bind:zoom>
	<div bind:this={contentElement} class="board" style="--cell-size: {cellSize}px">
		<BattleMap bind:size={dimensions} />

		{#if dimensions}
			<Overlay>
				<Grid {dimensions} {cellsPerRow} />
			</Overlay>

			<Overlay>
				{#each tokens as token (token.id)}
					<Token id={token.id} position={{ x: token.x, y: token.y }} size={token.size}></Token>
				{/each}
			</Overlay>
		{/if}
	</div>
</PanView>

<style>
	.board {
		position: relative;
		display: flex;
		align-self: center;
		pointer-events: stroke;
	}

	.board {
		pointer-events: none;
	}
</style>
