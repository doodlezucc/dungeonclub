<script lang="ts">
	import type { IconID } from './Icon.svelte';
	import Icon from './Icon.svelte';

	export let icon: IconID;
	export let label: string;
</script>

<button on:click class="icon" aria-label={label}>
	<Icon {icon} />
</button>
