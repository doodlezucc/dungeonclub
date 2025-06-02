<script lang="ts" module>
	import type { Position, Size } from '$lib/compounds';

	const minZoom = -1;
	const maxZoom = 3;
	const zoomStep = 0.25;

	function clampToBounds(position: Position, dimensions: Size) {
		const maxX = dimensions.width / 2;
		const maxY = dimensions.height / 2;
		const minX = -maxX;
		const minY = -maxY;

		let { x, y } = position;

		if (x < minX) x = minX;
		else if (x > maxX) x = maxX;

		if (y < minY) y = minY;
		else if (y > maxY) y = maxY;

		return { x, y };
	}

	function clampZoom(zoom: number) {
		return Math.min(Math.max(zoom, minZoom), maxZoom);
	}
</script>

<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		expand?: boolean;
		position?: any;
		zoom?: number;
		elementView?: HTMLElement | undefined;
		elementContent?: HTMLElement | undefined;

		onClick: () => void;

		children?: Snippet;
	}

	let {
		expand = false,
		position = $bindable({ x: 0, y: 0 }),
		zoom = $bindable(0),
		elementView = $bindable(undefined),
		elementContent = $bindable(undefined),
		onClick,
		children
	}: Props = $props();

	let elementsTriggeringPanEvent = $derived([elementView, elementContent] as EventTarget[]);

	let isPanning = $state(false);

	let hasPointerMovedSincePanStart = $state(false);

	let pointerOrigin = { x: 0, y: 0 };

	let scale = $derived(Math.exp(zoom));

	let dimensions = $state({
		width: 1,
		height: 1
	});

	function isValidPanEventStarter(eventTarget: EventTarget | null) {
		return eventTarget && elementsTriggeringPanEvent.includes(eventTarget);
	}

	function startPanning(ev: PointerEvent) {
		if (!isPanning) {
			const isMainMouseButton = ev.button == 0;

			if (!isMainMouseButton || isValidPanEventStarter(ev.target)) {
				ev.preventDefault();
				pointerOrigin = { x: ev.screenX, y: ev.screenY };
				isPanning = true;
				hasPointerMovedSincePanStart = false;
			}
		}
	}

	function stopPanning() {
		if (isPanning) {
			if (!hasPointerMovedSincePanStart) {
				onClick();
			}

			isPanning = false;
		}
	}

	function handlePointerMove(ev: PointerEvent) {
		if (!isPanning) return;

		hasPointerMovedSincePanStart = true;

		const offset = {
			x: (ev.screenX - pointerOrigin.x) / scale,
			y: (ev.screenY - pointerOrigin.y) / scale
		};

		position = clampToBounds(
			{
				x: position.x + offset.x,
				y: position.y + offset.y
			},
			dimensions
		);
		pointerOrigin = {
			x: ev.screenX,
			y: ev.screenY
		};
	}

	function handleMouseWheel(ev: WheelEvent) {
		const clamp = 0.1;
		const delta = ev.deltaY;
		const sign = delta >= 0 ? 1 : -1;

		const deltaClamped = sign * Math.min(Math.abs(delta), clamp);
		const deltaNormalized = deltaClamped / clamp;

		zoom = clampZoom(zoom - zoomStep * deltaNormalized);
	}
</script>

<svelte:document onpointermove={handlePointerMove} onpointerup={stopPanning} />

<div
	bind:this={elementView}
	class="pan-view"
	class:expand
	onpointerdown={startPanning}
	onwheel={handleMouseWheel}
	style="--x: {position.x}; --y: {position.y}; --scale: {scale};"
>
	<div
		bind:this={elementContent}
		class="panned"
		bind:clientWidth={dimensions.width}
		bind:clientHeight={dimensions.height}
	>
		{@render children?.()}
	</div>
</div>

<style>
	.pan-view {
		position: relative;
		display: flex;

		justify-content: center;
		overflow: hidden;
	}

	.panned {
		display: flex;
		align-self: center;

		transform: translate(calc(var(--x) * 1px), calc(var(--y) * 1px));
		scale: var(--scale);
		transition: scale 0.08s;
	}
</style>
