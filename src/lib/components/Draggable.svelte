<script lang="ts" context="module">
	import type { Action } from 'svelte/action';
	import type { Position } from './compounds';

	export interface DraggableParams {
		handleDragging: (mouseDelta: Position) => void;
		onDragToggle?: (isDragging: boolean) => void;
	}

	export const draggable: Action<HTMLElement, DraggableParams> = (node, params) => {
		node.draggable = true;

		function handleGlobalMouseMove(ev: MouseEvent) {
			console.log('drag update');
			params.handleDragging({
				x: ev.movementX,
				y: ev.movementY
			});
		}

		function handleDragStart(ev: DragEvent) {
			console.log('drag start');
			ev.preventDefault();
			if (params.onDragToggle) params.onDragToggle(true);

			window.addEventListener('mousemove', handleGlobalMouseMove);
			window.addEventListener('mouseup', handleGlobalMouseUp);
		}

		function handleGlobalMouseUp() {
			console.log('drag end');
			if (params.onDragToggle) params.onDragToggle(false);

			window.removeEventListener('mousemove', handleGlobalMouseMove);
		}

		node.addEventListener('dragstart', handleDragStart);

		return {
			destroy: () => {
				node.removeEventListener('dragstart', handleDragStart);
				window.removeEventListener('mouseup', handleGlobalMouseUp);
			}
		};
	};
</script>

<script lang="ts">
	import { spring } from 'svelte/motion';

	export let offset: Position = {
		x: 0,
		y: 0
	};

	let visualOffset = spring<Position>(offset, {
		stiffness: 0.1,
		damping: 0.4
	});
</script>

<div
	role="presentation"
	style="translate: {$visualOffset.x}px {$visualOffset.y}px;"
	use:draggable={{
		handleDragging: (mouseDelta) =>
			(offset = {
				x: offset.x + mouseDelta.x,
				y: offset.y + mouseDelta.y
			})
	}}
>
	<slot />
</div>
