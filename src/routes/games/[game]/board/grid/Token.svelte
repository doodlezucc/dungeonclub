<script lang="ts">
	import type { Position } from '$lib/kit/PanView.svelte';

	export let position: Position;

	export let size: number = 1;
</script>

<div class="token" style="--x: {position.x}; --y: {position.y}; --size: {size}">Token</div>

<style>
	.token {
		--size-px: calc(var(--cell-size) * var(--size));

		border-radius: 50%;
		border: 2px solid white;
		box-sizing: border-box;
		display: flex;
		align-items: center;
		justify-content: center;

		position: absolute;
		left: calc(var(--x) * var(--cell-size));
		top: calc(var(--y) * var(--cell-size));

		translate: calc(-0.5 * var(--size-px)) calc(-0.5 * var(--size-px));
		width: var(--size-px);
		height: var(--size-px);
	}
</style>
