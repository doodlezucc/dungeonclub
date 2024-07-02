<script lang="ts" generics="T">
	import { flip } from 'svelte/animate';
	import { fly } from 'svelte/transition';
	import Row from './layout/Row.svelte';

	export let items: Array<T>;

	$: modifiedItems = [...items, null] as Array<T>;
</script>

<Row gap="normal" wrap>
	{#each modifiedItems as item, index (item)}
		<div animate:flip in:fly|global={{ y: 30, delay: 200 + index * 50 }}>
			{#if item}
				<slot {item} />
			{:else}
				<slot name="plus" />
			{/if}
		</div>
	{/each}
</Row>

<style>
	div {
		display: flex;
	}
</style>
