<script lang="ts" module>
	export interface HistoryTokenMovement {
		tokenId: string;
		position: Record<Direction, Point>;
	}
</script>

<script lang="ts">
	import { socket } from '$lib/client/communication';
	import { Board, boardState } from '$lib/client/state';
	import type { TokenSnippet } from '$lib/net';
	import { derivedKeyStateModifySelection, keyStateOf } from '$lib/ui/util/ShortcutListener.svelte';
	import type { Point } from 'packages/math';
	import type { SelectionContext } from 'packages/ui';
	import type { Direction } from 'packages/undo-redo/action';
	import { historyOf } from 'packages/undo-redo/history';
	import { getContext } from 'svelte';
	import type { BoardContext } from '../Board.svelte';
	import TokenBase from './TokenBase.svelte';
	import * as Tokens from './token-management';

	interface Props {
		token: TokenSnippet;
		selected: boolean;
	}

	let { token, selected }: Props = $props();

	let position = $derived(<Point>{ x: token.x, y: token.y });
	let displaySize = $derived(token.size);

	const selection = getContext<SelectionContext<TokenSnippet>>('selection');

	const { transformClientToGridSpace } = getContext<BoardContext>('board');

	let isDragging = $state(false);

	let positionBeforeDragging = $state<Point>();
	let previousDragPosition = $state<Point>();

	function onDragToggle(dragState: boolean) {
		isDragging = dragState;

		if (dragState) {
			positionBeforeDragging = position;
			previousDragPosition = position;
		} else {
			onDraggedTo(position, positionBeforeDragging!);
		}
	}

	function onDraggedTo(position: Point, originalPosition: Point) {
		Tokens.submitTokenMovement(
			{
				selection: selection.getSelected(),
				delta: {
					x: position.x - originalPosition.x,
					y: position.y - originalPosition.y
				}
			},
			{
				boardHistory: historyOf($boardState!.id),
				socket: $socket
			}
		);
	}

	const activeGridSpace = Board.instance.grid.gridSpace;
	const isGridSnappingDisabled = keyStateOf('DisableGridSnapping');

	function handleDragging(ev: MouseEvent) {
		const mouseInGridSpace = transformClientToGridSpace({ x: ev.clientX, y: ev.clientY });

		let dragPosition: Point;

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

		const delta = <Point>{
			x: dragPosition.x - previousDragPosition!.x,
			y: dragPosition.y - previousDragPosition!.y
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

	const doModifySelection = derivedKeyStateModifySelection();

	function handleSelect() {
		selection.select(token, { additive: $doModifySelection });
	}
</script>

<TokenBase
	properties={token}
	{position}
	style={{
		selected,
		dragging: isDragging,
		transparent: false
	}}
	draggableParams={{
		onDragToggle,
		handleDragging
	}}
	onmousedown={() => {
		if (!selected) handleSelect();
	}}
	onmouseup={() => {
		const wasDraggedJustNow = isDragging;

		if (!wasDraggedJustNow) {
			if (selected) handleSelect();
		}
	}}
/>
