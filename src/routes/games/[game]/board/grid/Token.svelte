<script lang="ts">
	import type { Position } from '$lib/compounds';
	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { Board, boardState } from 'client/state';
	import { draggable } from 'components/Draggable.svelte';
	import { KeyState, keyStateOf } from 'components/extensions/ShortcutListener.svelte';
	import { getContext } from 'svelte';
	import { spring } from 'svelte/motion';
	import type { BoardContext } from '../Board.svelte';

	export let id: string;
	export let position: Position;
	export let size: number = 1;

	const activeGridSpace = Board.instance.grid.gridSpace;
	const isGridSnappingDisabled = keyStateOf(KeyState.DisableGridSnapping);

	$: isDragging = false;

	let originalPosition: Position;

	let positionSpring = spring(position, {
		damping: 0.7,
		stiffness: 0.2
	});

	$: {
		$positionSpring = position;
	}

	const { transformClientToGridSpace } = getContext<BoardContext>('board');

	function onDragToggle(dragState: boolean) {
		isDragging = dragState;

		if (dragState) {
			originalPosition = position;
		} else {
			historyOf($boardState!.id).registerDelta('Move token', {
				fromTo: [originalPosition, position],
				apply: (position) => {
					const payload = { id, position };

					$socket.send('tokenMove', payload);
					Board.instance.handleTokenMove(payload);
				}
			});
		}
	}

	function handleDragging(ev: MouseEvent) {
		const mouseInGridSpace = transformClientToGridSpace({ x: ev.clientX, y: ev.clientY });

		if ($isGridSnappingDisabled) {
			position = mouseInGridSpace;
		} else {
			const snapped = $activeGridSpace!.snapShapeToGrid({
				center: mouseInGridSpace,
				size
			});

			position = snapped;
		}
	}
</script>

<div
	class="token"
	class:dragging={isDragging}
	role="presentation"
	use:draggable={{ onDragToggle, handleDragging }}
	style="--x: {$positionSpring.x}; --y: {$positionSpring.y}; --size: {size}"
>
	Token
</div>

<style lang="scss">
	.token {
		--size-px: calc(var(--cell-size) * var(--size) * var(--cell-grow-factor));

		cursor: pointer;
		pointer-events: all;
		border-radius: 50%;
		border: 2px solid white;
		background-color: var(--color-background);
		box-sizing: border-box;
		display: flex;
		align-items: center;
		justify-content: center;

		position: absolute;
		left: calc(-0.5 * var(--size-px));
		top: calc(-0.5 * var(--size-px));

		translate: calc(var(--x) * var(--cell-size)) calc(var(--y) * var(--cell-size));
		width: var(--size-px);
		height: var(--size-px);

		outline: 1px solid transparent;
		outline-offset: 0.3em;
		transition:
			outline-offset 0.05s cubic-bezier(0.215, 0.61, 0.355, 1),
			outline 0.1s;

		&:hover,
		&.dragging {
			outline-color: white;
			outline-offset: 0.5em;
		}
	}
</style>
