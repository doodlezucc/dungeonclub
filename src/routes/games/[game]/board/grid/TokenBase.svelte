<script lang="ts" context="module">
	export interface TokenStyle {
		selected: boolean;
		dragging: boolean;
		transparent: boolean;
	}
</script>

<script lang="ts">
	import type { Position } from '$lib/compounds';
	import { draggable, type DraggableParams } from 'components/Draggable.svelte';
	import { spring } from 'svelte/motion';

	export let position: Position;
	export let size: number;

	export let style: TokenStyle;
	export let draggableParams: DraggableParams;

	const positionSpring = spring(position, {
		damping: 0.7,
		stiffness: 0.2
	});

	$: {
		$positionSpring = position;
	}
</script>

<div
	class="token"
	class:dragging={style.dragging}
	class:selected={style.selected}
	class:transparent={style.transparent}
	role="presentation"
	use:draggable={draggableParams}
	style="--x: {$positionSpring.x}; --y: {$positionSpring.y}; --size: {size}"
	on:mousedown
	on:mouseup
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

		&.selected {
			border-color: var(--color-primary);
		}

		&.transparent {
			opacity: 0.8;
		}
	}
</style>
