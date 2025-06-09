<script lang="ts">
	import type { Size } from 'packages/math';
	import type { Snippet } from 'svelte';

	interface Props {
		expand?: boolean;
		size?: Size | undefined;
		children?: Snippet;
	}

	let { expand = false, size = undefined, children }: Props = $props();
</script>

<div
	class:expand
	class:disable-margin={!!size}
	style={size ? `--width: ${size.width}px; --height: ${size.height}px;` : undefined}
>
	PLACEHOLDER
	{#if children}
		<br />
		({@render children()})
	{/if}
</div>

<style lang="scss">
	@function thin-line($direction) {
		@return linear-gradient(
			to $direction,
			transparent calc(50% - 1px),
			#fffa 50%,
			transparent calc(50% + 1px)
		);
	}

	div {
		background: thin-line(left bottom), thin-line(right bottom);
		outline: 2px dashed white;
		outline-offset: 2px;
		margin: 6px;
		padding: 2em;
		box-sizing: border-box;

		display: flex;
		text-align: center;
		align-items: center;
		justify-content: center;

		width: var(--width);
		height: var(--height);
	}

	.disable-margin {
		margin: 0;
		outline-offset: 0;
	}
</style>
