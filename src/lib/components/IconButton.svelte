<script lang="ts">
	import { createBubbler } from 'svelte/legacy';

	const bubble = createBubbler();
	import type { IconID } from './Icon.svelte';
	import Icon from './Icon.svelte';

	interface Props {
		icon: IconID;
		label: string;
		disabled?: boolean;
		disableMargin?: boolean;
		inline?: boolean;
	}

	let { icon, label, disabled = false, disableMargin = false, inline = false }: Props = $props();
</script>

<button
	onclick={bubble('click')}
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
