<script lang="ts">
	import type { Snippet } from 'svelte';
	import { createBubbler } from 'svelte/legacy';

	const bubble = createBubbler();
	interface Props {
		selected?: boolean;
		children: Snippet;
	}

	let { selected = false, children }: Props = $props();
</script>

<li class="list-tile" class:selected>
	<div
		role="button"
		class="custom"
		tabindex="0"
		onkeydown={bubble('keydown')}
		onclick={bubble('click')}
		onmousedown={bubble('mousedown')}
	>
		{@render children()}
	</div>
</li>

<style lang="scss">
	.list-tile {
		display: flex;
		background-color: var(--color-list-tile);
		min-height: 2rem;
		padding: 8px;

		&:hover {
			background-color: var(--color-list-tile-hover);
		}

		&.selected {
			background-color: var(--color-list-tile-selected);
		}
	}

	div {
		display: flex;
		cursor: default;
		flex: 1;
	}

	:global(.list-tile:not(:hover) button) {
		opacity: 0;
	}
</style>
