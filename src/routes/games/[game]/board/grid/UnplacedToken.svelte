<script lang="ts">
	import type { Position } from '$lib/compounds';
	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { Board, boardState } from 'client/state';
	import { allocateNewReference } from 'client/state/reference';
	import { KeyState, keyStateOf } from 'components/extensions/ShortcutListener.svelte';
	import type { TokenTemplateSnippet } from 'shared';
	import { getContext } from 'svelte';
	import { unplacedToken, type BoardContext } from '../Board.svelte';
	import TokenBase from './TokenBase.svelte';

	export let template: TokenTemplateSnippet;
	export let spawnPosition: Position;

	$: position = spawnPosition;

	function onDragToggle(isDragStart: boolean) {
		if (isDragStart) return;

		$unplacedToken = null;

		const boardId = $boardState!.id;
		const tokenIdHandle = allocateNewReference();

		historyOf(boardId).registerUndoable('Add token to board', async () => {
			const payload = await $socket.request('tokenCreate', {
				position: position,
				tokenTemplate: template.id
			});
			Board.instance.handleTokenCreate(payload);

			tokenIdHandle.set(payload.token.id);

			return {
				undo: () => {
					$socket.send('tokenDelete', {
						tokenId: tokenIdHandle.resolve()
					});
					Board.instance.handleTokenDelete({
						tokenId: tokenIdHandle.resolve()
					});
					tokenIdHandle.clear();
				}
			};
		});
	}

	const activeGridSpace = Board.instance.grid.gridSpace;
	const isGridSnappingDisabled = keyStateOf(KeyState.DisableGridSnapping);
	const { transformClientToGridSpace } = getContext<BoardContext>('board');

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
				size: template.size
			});

			position = snapped;
		}
	}
</script>

<TokenBase
	size={template.size}
	{position}
	style={{
		dragging: true,
		selected: true
	}}
	draggableParams={{
		autoDrag: true,
		handleDragging,
		onDragToggle
	}}
>
	{template.name}
</TokenBase>
