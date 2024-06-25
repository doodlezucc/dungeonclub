<script lang="ts" context="module">
	export type FlexDirection = 'column' | 'row';
	export type Gap = 'normal';
</script>

<script lang="ts">
	export let direction: FlexDirection | undefined = undefined;
	export let gap: Gap | undefined = undefined;

	export let expand = false;
</script>

<div class={direction} class:gap-normal={gap === 'normal'} class:expand>
	<slot />
</div>

<style>
	.gap-normal {
		gap: 0.3em;
	}
</style>
