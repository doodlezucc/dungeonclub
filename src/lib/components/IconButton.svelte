<script lang="ts" context="module">
	export type IconButtonSize = 'small';
</script>

<script lang="ts">
	import type { IconID } from './Icon.svelte';
	import Icon from './Icon.svelte';

	export let icon: IconID;
	export let label: string;
	export let disableMargin: boolean = false;
	export let size: IconButtonSize | undefined = undefined;
</script>

<button
	on:click
	class="icon"
	class:disable-margin={disableMargin}
	data-size={size}
	aria-label={label}
>
	<Icon {icon} />
</button>

<style>
	button:not(:hover, :active) {
		color: inherit;
	}
</style>
