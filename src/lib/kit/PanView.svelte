<script lang="ts">
	export let expand = false;

	$: isPanning = false;
	$: position = { x: 0, y: 0 };
	$: zoom = 0;

	$: scale = Math.exp(zoom);

	$: pointerOrigin = { x: 0, y: 0 };

	function startPanning(ev: PointerEvent) {
		ev.preventDefault();
		if (!isPanning) {
			pointerOrigin = { x: ev.screenX, y: ev.screenY };
			isPanning = true;
		}
	}

	function stopPanning() {
		isPanning = false;
	}

	function handlePointerMove(ev: PointerEvent) {
		if (!isPanning) return;

		const offset = {
			x: (ev.screenX - pointerOrigin.x) / scale,
			y: (ev.screenY - pointerOrigin.y) / scale
		};

		position = {
			x: position.x + offset.x,
			y: position.y + offset.y
		};
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

		zoom -= 0.5 * deltaNormalized;
	}
</script>

<svelte:document on:pointerup={stopPanning} />

<div
	class="pan-view"
	class:expand
	on:pointerdown={startPanning}
	on:pointermove={handlePointerMove}
	on:mousewheel={handleMouseWheel}
	style="--x: {position.x}; --y: {position.y}; --scale: {scale};"
>
	<div class="panned">
		<slot></slot>
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
		flex: 1;

		transform: translate(calc(var(--x) * 1px), calc(var(--y) * 1px));
		scale: var(--scale);
		transition: scale 0.08s;
	}
</style>
