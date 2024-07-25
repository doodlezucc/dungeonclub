<script lang="ts">
	import type { Position } from '$lib/compounds';
	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { Board, boardState } from 'client/state';
	import { allocateNewReference } from 'client/state/reference';
	import type { TokenTemplateSnippet } from 'shared';
	import { unplacedToken } from '../Board.svelte';
	import TokenBase from './TokenBase.svelte';

	export let template: TokenTemplateSnippet;
	export let spawnPosition: Position;

	function onDraggedTo(position: Position) {
		$unplacedToken = null;

		const boardId = $boardState!.id;
		const tokenIdHandle = allocateNewReference();

		historyOf(boardId).registerUndoable('Add token to board', async () => {
			const payload = await $socket.request('tokenCreate', {
				boardId: boardId,
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
</script>

<TokenBase
	autoDrag
	position={spawnPosition}
	{template}
	on:dragEnd={({ detail: { draggedPosition } }) => onDraggedTo(draggedPosition)}
>
	{template.name}
</TokenBase>
