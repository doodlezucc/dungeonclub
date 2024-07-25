<script lang="ts">
	import type { Position } from '$lib/compounds';
	import { Board } from 'client/state';
	import { draggable } from 'components/Draggable.svelte';
	import { KeyState, keyStateOf } from 'components/extensions/ShortcutListener.svelte';
	import type { TokenTemplateSnippet } from 'shared';
	import { createEventDispatcher, getContext } from 'svelte';
	import { spring } from 'svelte/motion';
	import type { BoardContext } from '../Board.svelte';

	export let template: TokenTemplateSnippet;
	export let position: Position;
	export let size: number = 1;
	export let autoDrag = false;

	$: displaySize = size == 0 ? template.size : size;

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

	const dispatch = createEventDispatcher<{
		dragEnd: {
			originalPosition: Position;
			draggedPosition: Position;
		};
	}>();

	const { transformClientToGridSpace } = getContext<BoardContext>('board');

	function onDragToggle(dragState: boolean) {
		isDragging = dragState;

		if (dragState) {
			originalPosition = position;
		} else {
			dispatch('dragEnd', {
				originalPosition,
				draggedPosition: position
			});
		}
	}

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
				size: displaySize
			});

			position = snapped;
		}
	}
</script>

<div
	class="token"
	class:dragging={isDragging}
	role="presentation"
	use:draggable={{ autoDrag, onDragToggle, handleDragging }}
	style="--x: {$positionSpring.x}; --y: {$positionSpring.y}; --size: {displaySize}"
>
	<slot />
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
