<script lang="ts" module>
	export interface BoardContext {
		transformClientToGridSpace: (position: Position) => Position;
		transformGridToClientSpace: (position: Position) => Position;
		getPanViewEventTarget(): EventTarget;
	}
</script>

<script lang="ts">
	import { Board, boardState } from '$lib/client/state/board';
	import type { Position, Size } from 'packages/math';
	import { PanView } from 'packages/ui';
	import { derivedKeyStateModifySelection } from 'packages/ui/extensions/ShortcutListener.svelte';
	import { Overlay } from 'packages/ui/layout';
	import { setContext } from 'svelte';
	import BattleMap from './BattleMap.svelte';
	import BoardTokens from './BoardTokens.svelte';
	import Grid from './grid/Grid.svelte';

	interface Props {
		selectedTokenIds?: string[];
	}

	let { selectedTokenIds = $bindable([]) }: Props = $props();

	const activeGridSpace = Board.instance.grid.gridSpace;
	const tileHeightRatio = $activeGridSpace?.tileHeightRatio ?? 1;

	const cellsPerRow = $boardState!.gridCellsPerRow;

	let position = $state<Position>({ x: 0, y: 0 });
	let zoom = $state(0);

	let dimensions = $state<Size>();

	let cellSize = $derived((dimensions?.width ?? 0) / cellsPerRow);

	let tokenContainer = $state<BoardTokens>();

	let contentElement = $state<HTMLElement>();
	let cachedClientRect: DOMRect | undefined = undefined;

	$effect(() => {
		// Clear cached client rect when position or zoom changes
		if (position && zoom != undefined) {
			cachedClientRect = undefined;
		}
	});

	const keepTokenSelection = derivedKeyStateModifySelection();
	function onClickEmptySpace() {
		if (!$keepTokenSelection) {
			tokenContainer!.clearSelection();
		}
	}

	function getClientRect() {
		return (cachedClientRect ??= contentElement!.getBoundingClientRect());
	}

	function transformClientToGridSpace(clientPosition: Position): Position {
		const rect = getClientRect();

		const zoomFactor = Math.exp(zoom);
		const factor = zoomFactor * cellSize;

		return {
			x: (clientPosition.x - rect.x) / factor,
			y: (clientPosition.y - rect.y) / (factor * tileHeightRatio)
		};
	}

	function transformGridToClientSpace(position: Position): Position {
		throw 'Not implemented';
	}

	let panViewElement: HTMLElement | undefined = $state();

	setContext<BoardContext>('board', {
		transformClientToGridSpace,
		transformGridToClientSpace,

		getPanViewEventTarget: () => panViewElement!
	});
</script>

<PanView
	expand
	bind:position
	bind:zoom
	bind:elementView={panViewElement}
	bind:elementContent={contentElement}
	onClick={onClickEmptySpace}
>
	<div class="board" style="--cell-size: {cellSize}px; --cell-grow-factor: {tileHeightRatio};">
		<BattleMap bind:size={dimensions} />

		{#if dimensions}
			<Overlay>
				<Grid {dimensions} {cellsPerRow} />
			</Overlay>

			<Overlay>
				<BoardTokens bind:this={tokenContainer} bind:selectedTokenIds />
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
