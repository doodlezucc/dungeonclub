<script lang="ts">
	import type { Position } from '$lib/compounds';
	import { Board } from 'client/state';
	import { draggable } from 'components/Draggable.svelte';
	import { getContext } from 'svelte';
	import { spring } from 'svelte/motion';
	import type { BoardContext } from '../Board.svelte';

	export let position: Position;
	export let size: number = 1;

	let activeGridSpace = Board.instance.grid.gridSpace;

	let originalPosition: Position;

	let positionSpring = spring(position, {
		damping: 0.7,
		stiffness: 0.2
	});

	$: {
		$positionSpring = position;
	}

	const { transformClientToGridSpace } = getContext<BoardContext>('board');

	function onDragToggle(isDragging: boolean) {
		if (isDragging) {
			originalPosition = position;
		}
	}

	function handleDragging(ev: MouseEvent) {
		const mouseInGridSpace = transformClientToGridSpace({ x: ev.clientX, y: ev.clientY });

		const snapped = $activeGridSpace!.snapShapeToGrid({
			center: mouseInGridSpace,
			size
		});

		position = snapped;
	}
</script>

<div
	class="token"
	role="presentation"
	use:draggable={{ onDragToggle, handleDragging }}
	style="--x: {$positionSpring.x}; --y: {$positionSpring.y}; --size: {size}"
>
	Token
</div>

<style>
	.token {
		--size-px: calc(var(--cell-size) * var(--size));

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
	}
</style>
