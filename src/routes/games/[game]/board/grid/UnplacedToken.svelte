<script lang="ts">
	import type { Position } from '$lib/compounds';
	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { Board, boardState } from 'client/state';
	import type { TokenTemplateSnippet } from 'shared';
	import { unplacedToken } from '../Board.svelte';
	import TokenBase from './TokenBase.svelte';

	export let template: TokenTemplateSnippet;
	export let spawnPosition: Position;

	function onDraggedTo(position: Position) {
		$unplacedToken = null;

		const boardId = $boardState!.id;
		let tokenId: string | undefined;

		historyOf(boardId).registerUndoable('Add token to board', async () => {
			const payload = await $socket.request('tokenCreate', {
				boardId: boardId,
				position: position,
				tokenTemplate: template.id
			});
			Board.instance.handleTokenCreate(payload);

			tokenId = payload.token.id;

			return {
				undo: () => {
					$socket.send('tokenDelete', {
						tokenId: tokenId!
					});
					Board.instance.handleTokenDelete({ tokenId: tokenId! });
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
