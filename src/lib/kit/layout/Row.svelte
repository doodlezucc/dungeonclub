<script lang="ts">
	import Container from './Container.svelte';

	export let expand = false;
</script>

<Container direction="row" {expand}><slot /></Container>
