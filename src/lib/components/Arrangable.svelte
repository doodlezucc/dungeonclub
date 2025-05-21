<script lang="ts">
	import { run } from 'svelte/legacy';

	import { createEventDispatcher, type Snippet } from 'svelte';
	import { spring } from 'svelte/motion';
	import type { DragState } from './ArrangedCollection.svelte';
	import type { Position } from './compounds';

	interface Props {
		index: number;
		state: DragState;
		customDragHandling: boolean;
		children?: Snippet;
	}

	let { index, state: dragState, customDragHandling, children }: Props = $props();

	let isDragging = dragState.controller.isDragging;
	let isAnyDragging = dragState.isAnyDragging;

	let mouseOffset;
	run(() => {
		mouseOffset = undefined as Position | undefined;
	});

	let visualCenter = spring<Position>(undefined, {
		stiffness: 0.1,
		damping: 0.4
	});

	let center = $state<Position>();
	let draggedCenter = $state<Position>();

	let container = $state<HTMLElement>();

	run(() => {
		if (!$isDragging) {
			mouseOffset = undefined;
			draggedCenter = center;
		}
	});

	function findCenter() {
		const rect = container!.getBoundingClientRect();
		center = {
			x: rect.left + rect.width / 2,
			y: rect.top + rect.height / 2
		};
		if (!$isDragging) {
			$visualCenter = center;
		}
		dragState.setItemCenter(center);
	}

	run(() => {
		if (container && $isAnyDragging && index !== undefined) {
			findCenter();
		}
	});

	let visualOffset = $derived(
		$visualCenter && center
			? {
					x: $visualCenter.x - center!.x,
					y: $visualCenter.y - center!.y
				}
			: { x: 0, y: 0 }
	);

	const dispatch = createEventDispatcher();

	run(() => {
		if (draggedCenter) {
			dispatch('drag');
			$visualCenter = draggedCenter;
		}
	});

	function handleMouseMove(ev: PointerEvent) {
		mouseOffset ??= {
			x: ev.clientX - center!.x,
			y: ev.clientY - center!.y
		};

		draggedCenter = {
			x: ev.clientX - mouseOffset.x,
			y: ev.clientY - mouseOffset.y
		};
	}

	function onDragContainer(ev: DragEvent) {
		ev.preventDefault();

		if (!customDragHandling) {
			dragState.controller.start();
		}
	}
</script>

<svelte:window onpointermove={$isDragging ? handleMouseMove : undefined} />

<div
	class="arrangable"
	class:dragging={$isDragging}
	role="listitem"
	draggable="true"
	ondragstart={onDragContainer}
>
	<div class="expand ghost" bind:this={container}></div>
	<div class="expand" style="translate: {visualOffset.x}px {visualOffset.y}px;">
		{@render children?.()}
	</div>
</div>

<style>
	.arrangable {
		position: relative;
	}

	.expand {
		display: flex;
		width: 100%;
		height: 100%;
	}

	.ghost {
		position: absolute;
		outline: 1px solid transparent;
	}

	.dragging * {
		pointer-events: none;
	}

	.dragging .ghost {
		outline: 2px dashed white;
	}
</style>
