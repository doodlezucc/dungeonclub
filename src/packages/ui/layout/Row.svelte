<script lang="ts">
	import type { Snippet } from 'svelte';
	import Flex, { type FlexAlign, type FlexJustify, type Gap } from './Flex.svelte';

	interface Props {
		expand?: boolean;
		wrap?: boolean;
		gap?: Gap | undefined;
		align?: FlexAlign | undefined;
		justify?: FlexJustify | undefined;
		children: Snippet;
	}

	let {
		expand = false,
		wrap = false,
		gap = undefined,
		align = undefined,
		justify = undefined,
		children
	}: Props = $props();
</script>

<Flex direction="row" {expand} {wrap} {gap} {align} {justify}>
	{@render children()}
</Flex>
