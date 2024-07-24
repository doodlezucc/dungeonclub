<script lang="ts" generics="T">
	import { flip } from 'svelte/animate';
	import { fly } from 'svelte/transition';

	export let items: Array<T>;
	export let itemClass: string | undefined = undefined;

	$: modifiedItems = [...items, null] as Array<T>;
</script>

{#each modifiedItems as item, index (item)}
	<div
		class={item !== null ? itemClass : undefined}
		animate:flip={{ duration: 200 }}
		in:fly|global={{ y: 30, delay: 200 + index * 50 }}
	>
		{#if item !== null}
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
