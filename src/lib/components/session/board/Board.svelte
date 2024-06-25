<script lang="ts">
	import Placeholder from '$lib/kit/layout/Placeholder.svelte';
	import PanView from '$lib/kit/PanView.svelte';

	let transform = { x: 0, y: 0, zoom: 1 };
</script>

<PanView expand>
	<Placeholder expand>Grid</Placeholder>
</PanView>
