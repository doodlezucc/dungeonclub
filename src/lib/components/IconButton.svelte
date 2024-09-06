<script lang="ts">
	import type { IconID } from './Icon.svelte';
	import Icon from './Icon.svelte';

	export let icon: IconID;
	export let label: string;
	export let disableMargin: boolean = false;
</script>

<button on:click class="icon" class:disable-margin={disableMargin} aria-label={label}>
	<Icon {icon} />
</button>
