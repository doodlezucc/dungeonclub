<script lang="ts" context="module">
	export type CollectionItem = {
		id: any;
	};
</script>

<script lang="ts" generics="T extends CollectionItem">
	import Row from '$lib/kit/layout/Row.svelte';
	import { flip } from 'svelte/animate';
	import { fly } from 'svelte/transition';

	export let items: Array<T>;

	$: modifiedItems = [...items, null] as Array<T>;
</script>

<Row gap="normal" align="center" wrap>
	{#each modifiedItems as item, index (item?.id)}
		<div animate:flip in:fly|global={{ y: 30, delay: 200 + index * 50 }}>
			{#if item}
				<slot {item} />
			{:else}
				<slot name="plus" />
			{/if}
		</div>
	{/each}
</Row>
