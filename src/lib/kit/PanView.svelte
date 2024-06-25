<script lang="ts">
	export let expand = false;

	type Position = {
		x: number;
		y: number;
	};

	$: position = { x: 0, y: 0 };
	$: zoom = 0;

	$: isPanning = false;
	$: pointerOrigin = { x: 0, y: 0 };

	$: scale = Math.exp(zoom);

	let dimensions = {
		width: 1,
		height: 1
	};

	function clampToBounds(position: Position) {
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

		position = clampToBounds({
			x: position.x + offset.x,
			y: position.y + offset.y
		});
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

<svelte:document on:pointermove={handlePointerMove} on:pointerup={stopPanning} />

<div
	class="pan-view"
	class:expand
	bind:clientWidth={dimensions.width}
	bind:clientHeight={dimensions.height}
	on:pointerdown={startPanning}
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
