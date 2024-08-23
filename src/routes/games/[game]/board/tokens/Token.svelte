<script lang="ts" context="module">
	export interface HistoryTokenMovement {
		tokenReference: Reference;
		position: Record<Direction, Position>;
	}
</script>

<script lang="ts">
	import type { Position } from '$lib/compounds';
	import type { Direction } from '$lib/packages/undo-redo/action';
	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { Board, boardState } from 'client/state';
	import { referenceTo, type Reference } from 'client/state/reference';
	import { KeyState, keyStateOf } from 'components/extensions/ShortcutListener.svelte';
	import type { SelectionContext } from 'components/groups/SelectionGroup.svelte';
	import type { GetPayload, TokenSnippet, TokenTemplateSnippet } from 'shared';
	import { getContext } from 'svelte';
	import { derived } from 'svelte/store';
	import type { BoardContext } from '../Board.svelte';
	import TokenBase from './TokenBase.svelte';

	export let token: TokenSnippet;
	export let template: TokenTemplateSnippet;
	export let selected: boolean;

	$: position = <Position>{ x: token.x, y: token.y };
	const displaySize = token.size === null ? template.size : token.size;

	const selection = getContext<SelectionContext<TokenSnippet>>('selection');

	const { transformClientToGridSpace } = getContext<BoardContext>('board');

	$: isDragging = false;
	let positionBeforeDragging = position;
	let previousDragPosition = position;

	function onDragToggle(dragState: boolean) {
		isDragging = dragState;

		if (dragState) {
			positionBeforeDragging = position;
			previousDragPosition = position;
		} else {
			onDraggedTo(position, positionBeforeDragging);
		}
	}

	function submitPositionDelta(delta: Position) {
		const tokenMovements = selection.map((selectedToken) => {
			const newPosition = <Position>{
				x: selectedToken.x,
				y: selectedToken.y
			};

			const originalPosition = <Position>{
				x: newPosition.x - delta.x,
				y: newPosition.y - delta.y
			};

			return {
				tokenReference: referenceTo(selectedToken.id),
				position: <Record<Direction, Position>>{
					forward: newPosition,
					backward: originalPosition
				}
			};
		});

		const actionName = tokenMovements.length === 1 ? 'Move token' : 'Move tokens';

		historyOf($boardState!.id).registerDirectional(actionName, (direction) => {
			const payload: GetPayload<'tokensMove'> = {};

			for (const movement of tokenMovements) {
				const tokenId = movement.tokenReference.resolve();
				const position = movement.position[direction];
				payload[tokenId] = position;
			}

			$socket.send('tokensMove', payload);
			Board.instance.handleTokensMove(payload);
		});
	}

	function onDraggedTo(position: Position, originalPosition: Position) {
		submitPositionDelta({
			x: position.x - originalPosition.x,
			y: position.y - originalPosition.y
		});
	}

	const activeGridSpace = Board.instance.grid.gridSpace;
	const isGridSnappingDisabled = keyStateOf(KeyState.DisableGridSnapping);

	function handleDragging(ev: MouseEvent) {
		const mouseInGridSpace = transformClientToGridSpace({ x: ev.clientX, y: ev.clientY });

		let dragPosition: Position;

		if ($isGridSnappingDisabled) {
			dragPosition = {
				x: mouseInGridSpace.x,
				y: mouseInGridSpace.y * $activeGridSpace!.tileHeightRatio
			};
		} else {
			const snapped = $activeGridSpace!.snapShapeToGrid({
				center: mouseInGridSpace,
				size: displaySize
			});

			dragPosition = snapped;
		}

		const delta = <Position>{
			x: dragPosition.x - previousDragPosition.x,
			y: dragPosition.y - previousDragPosition.y
		};

		previousDragPosition = dragPosition;

		Board.instance.put((board) => ({
			...board,
			tokens: board.tokens.map((token) => {
				if (selection.includes(token)) {
					return {
						...token,
						x: token.x + delta.x,
						y: token.y + delta.y
					};
				}

				return token;
			})
		}));
	}

	const doModifySelection = derived(
		[keyStateOf(KeyState.ModifySelection), keyStateOf(KeyState.ModifySelectionRange)],
		([doModify, doModifyRange]) => {
			return doModify || doModifyRange;
		}
	);

	function handleSelect() {
		selection.select(token, { additive: $doModifySelection });
	}
</script>

<TokenBase
	{template}
	{position}
	size={displaySize}
	style={{
		selected,
		dragging: isDragging,
		transparent: false
	}}
	draggableParams={{
		onDragToggle,
		handleDragging
	}}
	on:mousedown={() => {
		if (!selected) handleSelect();
	}}
	on:mouseup={() => {
		const wasDraggedJustNow = isDragging;

		if (!wasDraggedJustNow) {
			if (selected) handleSelect();
		}
	}}
/>
