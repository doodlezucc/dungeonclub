<script lang="ts">
	import Placeholder from '$lib/kit/layout/Placeholder.svelte';
	import type { Dimensions } from '$lib/kit/PanView.svelte';

	export let dimensions: Dimensions;
</script>

<Placeholder size={dimensions}>Battle Map</Placeholder>
