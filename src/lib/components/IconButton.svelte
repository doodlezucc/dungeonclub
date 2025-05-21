<script lang="ts">
	import type { MouseEventHandler } from 'svelte/elements';
	import type { IconID } from './Icon.svelte';
	import Icon from './Icon.svelte';

	interface Props {
		icon: IconID;
		label: string;
		disabled?: boolean;
		disableMargin?: boolean;
		inline?: boolean;

		onclick?: MouseEventHandler<HTMLButtonElement>;
	}

	let {
		icon,
		label,
		disabled = false,
		disableMargin = false,
		inline = false,
		onclick
	}: Props = $props();
</script>

<button
	{onclick}
	class="icon"
	class:disable-margin={disableMargin}
	class:inline
	{disabled}
	aria-label={label}
>
	<Icon {icon} />
</button>

<style>
	button:not(:hover, :active) {
		color: inherit;
	}
</style>
