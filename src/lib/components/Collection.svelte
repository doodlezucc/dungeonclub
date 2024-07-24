<script lang="ts" generics="T">
	import { flip } from 'svelte/animate';
	import { fly } from 'svelte/transition';

	export let items: Array<T>;

	$: modifiedItems = [...items, null] as Array<T>;
</script>

{#each modifiedItems as item, index (item)}
	<div animate:flip in:fly|global={{ y: 30, delay: 200 + index * 50 }}>
		{#if item}
			<slot {item} />
		{:else}
			<slot name="plus" />
		{/if}
	</div>
{/each}

<style>
	div {
		display: flex;
		flex-direction: inherit;
	}
</style>
