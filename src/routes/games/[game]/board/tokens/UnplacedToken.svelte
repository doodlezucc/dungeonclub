<script lang="ts" context="module">
	import { writable } from 'svelte/store';

	export interface UnplacedTokenProperties {
		tokenTemplate?: TokenTemplateSnippet;
		triggeringEvent: MouseEvent;
	}

	export const unplacedTokenProperties = writable<UnplacedTokenProperties | null>(null);
</script>

<script lang="ts">
	import type { Position } from '$lib/compounds';
	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { Board, boardState } from 'client/state';
	import { allocateNewReference } from 'client/state/reference';
	import { KeyState, keyStateOf } from 'components/extensions/ShortcutListener.svelte';
	import type { GetPayload, TokenSnippet, TokenTemplateSnippet } from 'shared';
	import { createEventDispatcher, getContext } from 'svelte';
	import type { BoardContext } from '../Board.svelte';
	import TokenBase from './TokenBase.svelte';

	export let template: TokenTemplateSnippet | undefined;
	export let spawnPosition: Position;

	$: position = spawnPosition;

	const dispatch = createEventDispatcher<{
		instantiate: TokenSnippet;
	}>();

	function onDragToggle(isDragStart: boolean) {
		if (isDragStart) return;

		$unplacedTokenProperties = null;

		const boardId = $boardState!.id;
		const tokenIdHandle = allocateNewReference();

		let isInitialCreation = true;

		historyOf(boardId).registerUndoable('Add token to board', async () => {
			const response = await $socket.request('tokensCreate', {
				newTokens: [
					{
						x: position.x,
						y: position.y,
						templateId: template?.id ?? null
					}
				]
			});
			Board.instance.handleTokensCreate(response);

			const instantiatedToken = response.tokens[0];

			if (isInitialCreation) {
				dispatch('instantiate', instantiatedToken);
				isInitialCreation = false;
			}

			tokenIdHandle.set(instantiatedToken.id);

			return {
				undo: () => {
					const payload: GetPayload<'tokensDelete'> = {
						tokenIds: [tokenIdHandle.resolve()]
					};

					$socket.send('tokensDelete', payload);
					Board.instance.handleTokensDelete(payload);

					tokenIdHandle.clear();
				}
			};
		});
	}

	const activeGridSpace = Board.instance.grid.gridSpace;
	const isGridSnappingDisabled = keyStateOf(KeyState.DisableGridSnapping);
	const { transformClientToGridSpace } = getContext<BoardContext>('board');

	$: size = template?.size ?? 1;

	function handleDragging(ev: MouseEvent) {
		const mouseInGridSpace = transformClientToGridSpace({ x: ev.clientX, y: ev.clientY });

		if ($isGridSnappingDisabled) {
			position = {
				x: mouseInGridSpace.x,
				y: mouseInGridSpace.y * $activeGridSpace!.tileHeightRatio
			};
		} else {
			const snapped = $activeGridSpace!.snapShapeToGrid({
				center: mouseInGridSpace,
				size: size
			});

			position = snapped;
		}
	}
</script>

<TokenBase
	{template}
	{size}
	{position}
	style={{
		dragging: true,
		selected: true,
		transparent: true
	}}
	draggableParams={{
		autoDrag: true,
		handleDragging,
		onDragToggle
	}}
/>
