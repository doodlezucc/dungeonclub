<script lang="ts" context="module">
	import type { TokenSnippet, TokenTemplateSnippet } from 'shared';

	export interface BoardContext {
		transformClientToGridSpace: (position: Position) => Position;
		transformGridToClientSpace: (position: Position) => Position;
	}

	interface UnplacedTokenOptions {
		tokenTemplate: TokenTemplateSnippet;
		triggeringEvent: MouseEvent;
	}

	export const unplacedToken = writable<UnplacedTokenOptions | null>(null);
</script>

<script lang="ts">
	import type { Position, Size } from '$lib/compounds';
	import { sessionState } from 'client/state';
	import { Board, boardState } from 'client/state/board';
	import { PanView } from 'components';
	import SelectionGroup from 'components/groups/SelectionGroup.svelte';
	import { Overlay } from 'components/layout';
	import { setContext } from 'svelte';
	import { derived, writable } from 'svelte/store';
	import BattleMap from './BattleMap.svelte';
	import Grid from './grid/Grid.svelte';
	import Token from './grid/Token.svelte';
	import UnplacedToken from './grid/UnplacedToken.svelte';

	const activeGridSpace = Board.instance.grid.gridSpace;
	const tileHeightRatio = $activeGridSpace?.tileHeightRatio ?? 1;

	const cellsPerRow = $boardState!.gridCellsPerRow;

	$: position = <Position>{ x: 0, y: 0 };
	$: zoom = 0;

	$: dimensions = undefined as Size | undefined;

	$: cellSize = (dimensions?.width ?? 0) / cellsPerRow;

	$: tokens = $boardState!.tokens;
	$: tokenTemplates = $sessionState.campaign!.templates;

	const loadedBoardId = derived(boardState, (board) => board!.id);

	function getTemplateForToken(token: TokenSnippet) {
		return tokenTemplates.find((template) => template.id === token.templateId)!;
	}

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
			y: (clientPosition.y - rect.y) / (factor * tileHeightRatio)
		};
	}

	function transformGridToClientSpace(position: Position): Position {
		throw 'Not implemented';
	}

	setContext<BoardContext>('board', {
		transformClientToGridSpace,
		transformGridToClientSpace
	});

	$: unplacedTokenSpawnPosition = $unplacedToken
		? transformClientToGridSpace({
				x: $unplacedToken.triggeringEvent.clientX,
				y: $unplacedToken.triggeringEvent.clientY
			})
		: null;

	$: tokenSelectionGroup = null as SelectionGroup<TokenSnippet> | null;

	$: {
		if ($loadedBoardId) {
			// Called whenever a board gets loaded
			tokenSelectionGroup?.clear();
		}
	}
</script>

<PanView expand bind:position bind:zoom>
	<div
		bind:this={contentElement}
		class="board"
		style="--cell-size: {cellSize}px; --cell-grow-factor: {tileHeightRatio};"
	>
		<BattleMap bind:size={dimensions} />

		{#if dimensions}
			<Overlay>
				<Grid {dimensions} {cellsPerRow} />
			</Overlay>

			<Overlay>
				<SelectionGroup
					bind:this={tokenSelectionGroup}
					elements={tokens}
					toKey={(token) => token.id}
					let:element={token}
					let:isSelected
				>
					<Token {token} template={getTemplateForToken(token)} selected={isSelected} />
				</SelectionGroup>

				{#if $unplacedToken && unplacedTokenSpawnPosition}
					{#key $unplacedToken.tokenTemplate.id}
						<UnplacedToken
							template={$unplacedToken.tokenTemplate}
							spawnPosition={unplacedTokenSpawnPosition}
						/>
					{/key}
				{/if}
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
