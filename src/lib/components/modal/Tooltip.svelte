<script lang="ts" context="module">
	export interface TooltipProps {
		label: string;
	}

	/** Minimum duration needed to ensure a smooth fade-out before detaching a tooltip component. */
	export const TOOLTIP_TRANSITION_OUT_MS = 200;

	function rectToCssVariableMap(rect: DOMRect) {
		return {
			'--x': `${rect.x}px`,
			'--y': `${rect.y}px`,
			'--w': `${rect.width}px`,
			'--h': `${rect.height}px`
		};
	}

	function composeRectStyleProperty(rect: DOMRect) {
		const entries = Object.entries(rectToCssVariableMap(rect));

		return entries.map(([key, value]) => `${key}: ${value};`).join(' ');
	}
</script>

<script lang="ts">
	import { onMount } from 'svelte';

	import { fly } from 'svelte/transition';

	export let props: TooltipProps;
	export let boundingRect: DOMRect;
	export let isDestroyed = false;

	$: isMounted = false;

	onMount(() => {
		isMounted = true;
	});
</script>

{#if isMounted && !isDestroyed}
	<div
		class="tooltip-wrapper"
		style={composeRectStyleProperty(boundingRect)}
		transition:fly={{ y: 20, duration: TOOLTIP_TRANSITION_OUT_MS }}
	>
		<span>{props.label}</span>
	</div>
{/if}

<style>
	.tooltip-wrapper {
		position: absolute;
		left: var(--x);
		top: var(--y);
		width: var(--w);
		height: var(--h);

		outline: 1px solid red;
	}

	span {
		background-color: var(--color-background);
		padding: 0.5em;
	}
</style>
