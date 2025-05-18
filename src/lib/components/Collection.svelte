<script lang="ts" module>
	const PLUS_ITEM_TOKEN = {};
</script>

<script lang="ts" generics="T">
	import { flip } from 'svelte/animate';
	import { fly } from 'svelte/transition';

	function identity<T>(x: T) {
		return x;
	}

	interface Props {
		items: Array<T>;
		itemClass?: string | undefined;
		keyFunction?: (item: T) => unknown;
		children?: import('svelte').Snippet<[any]>;
		plus?: import('svelte').Snippet;
	}

	let {
		items,
		itemClass = undefined,
		keyFunction = identity,
		children,
		plus
	}: Props = $props();

	function keyOf(itemOrPlus: T) {
		if (itemOrPlus === PLUS_ITEM_TOKEN) {
			return PLUS_ITEM_TOKEN;
		}

		return keyFunction(itemOrPlus);
	}

	let modifiedItems = $derived([...items, PLUS_ITEM_TOKEN] as Array<T>);
</script>

{#each modifiedItems as item, index (keyOf(item))}
	<div
		class={item !== PLUS_ITEM_TOKEN ? itemClass : undefined}
		animate:flip={{ duration: 200 }}
		in:fly|global={{ y: 30, delay: 200 + index * 50 }}
	>
		{#if item !== PLUS_ITEM_TOKEN}
			{@render children?.({ item, })}
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
