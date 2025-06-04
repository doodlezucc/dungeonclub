<script lang="ts" module>
	const PLUS_ITEM_TOKEN = {};
</script>

<script lang="ts" generics="T">
	import type { Snippet } from 'svelte';

	import { flip } from 'svelte/animate';
	import type { ClassValue } from 'svelte/elements';
	import { fly } from 'svelte/transition';

	function identity<T>(x: T) {
		return x;
	}

	interface Props {
		items: Array<T>;
		itemClass?: ClassValue;
		keyFunction?: (item: T) => unknown;
		children?: Snippet<[any]>;
		plus?: Snippet;
	}

	let { items, itemClass, keyFunction = identity, children, plus }: Props = $props();

	function keyOf(itemOrPlus: T | typeof PLUS_ITEM_TOKEN) {
		if (itemOrPlus === PLUS_ITEM_TOKEN) {
			return PLUS_ITEM_TOKEN;
		}

		return keyFunction(itemOrPlus as T);
	}

	let itemsWithPlusToken = $derived.by(() => {
		if (plus) {
			return [...items, PLUS_ITEM_TOKEN];
		} else {
			return items;
		}
	});
</script>

{#each itemsWithPlusToken as item, index (keyOf(item))}
	<div
		class={item !== PLUS_ITEM_TOKEN ? itemClass : undefined}
		animate:flip={{ duration: 200 }}
		in:fly|global={{ y: 30, delay: 200 + index * 50 }}
	>
		{#if item !== PLUS_ITEM_TOKEN}
			{@render children?.({ item })}
		{:else}
			{@render plus?.()}
		{/if}
	</div>
{/each}

<style>
	div {
		display: flex;
		flex-direction: inherit;
	}
</style>
