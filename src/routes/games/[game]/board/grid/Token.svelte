<script lang="ts">
	import type { Position } from '$lib/compounds';
	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { Board, boardState } from 'client/state';
	import type { TokenTemplateSnippet } from 'shared';
	import TokenBase from './TokenBase.svelte';

	export let id: string;
	export let template: TokenTemplateSnippet;
	export let position: Position;

	export let size: number = 1;

	function onDraggedTo(position: Position, originalPosition: Position) {
		historyOf($boardState!.id).registerDelta('Move token', {
			fromTo: [originalPosition, position],
			apply: (position) => {
				const payload = { id, position };

				$socket.send('tokenMove', payload);
				Board.instance.handleTokenMove(payload);
			}
		});
	}
</script>

<TokenBase
	{template}
	bind:position
	bind:size
	on:dragEnd={({ detail: { draggedPosition, originalPosition } }) =>
		onDraggedTo(draggedPosition, originalPosition)}
>
	Token
</TokenBase>
