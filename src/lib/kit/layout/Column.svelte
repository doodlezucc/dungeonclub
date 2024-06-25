<script lang="ts">
	import Container, { type Gap } from './Container.svelte';

	export let expand = false;
	export let gap: Gap | undefined = undefined;
</script>

<Container direction="column" {expand} {gap}><slot /></Container>
