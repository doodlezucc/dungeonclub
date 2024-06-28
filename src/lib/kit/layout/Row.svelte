<script lang="ts">
	import Container, { type FlexAlign, type FlexJustify, type Gap } from './Flex.svelte';

	export let expand = false;
	export let gap: Gap | undefined = undefined;

	export let align: FlexAlign | undefined = undefined;
	export let justify: FlexJustify | undefined = undefined;
</script>

<Container direction="row" {expand} {gap} {align} {justify}><slot /></Container>
