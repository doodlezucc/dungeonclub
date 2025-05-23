<script lang="ts" module>
	export interface SelectOptions {
		additive: boolean;
	}

	export interface SelectionContext<T> {
		getSelected(): T[];
		select(element: T, options: SelectOptions): void;

		includes(element: T): boolean;
	}
</script>

<script lang="ts" generics="T">
	import { run } from 'svelte/legacy';

	import { setContext, type Snippet } from 'svelte';

	interface Props {
		elements: T[];
		getElementKey: (element: T) => string;
		selectedKeys?: string[];
		selectedElements?: T[];
		children?: Snippet<[any]>;
	}

	let {
		elements,
		getElementKey,
		selectedKeys = $bindable([]),
		selectedElements = $bindable([]),
		children
	}: Props = $props();

	run(() => {
		const staleKeys = selectedKeys.filter(
			(key) => !elements.some((element) => getElementKey(element) === key)
		);

		if (staleKeys.length > 0) {
			// Remove stale keys of elements which are no longer part of the `elements` array.
			selectedKeys = selectedKeys.filter((key) => !staleKeys.includes(key));
		}

		// The order in which elements get selected stays consistent.
		// When selecting a new element, it will be placed at the end of the array.
		selectedElements = selectedKeys.map(
			(key) => elements.find((element) => getElementKey(element) === key)!
		);
	});

	export function clear() {
		selectedKeys = [];
	}

	export function select(element: T, { additive }: SelectOptions) {
		const key = getElementKey(element);

		if (additive) {
			if (!selectedKeys.includes(key)) {
				selectedKeys = [...selectedKeys, key];
			}
		} else {
			selectedKeys = [key];
		}
	}

	setContext<SelectionContext<T>>('selection', {
		getSelected: () => selectedElements,
		select,

		includes: (element) => selectedKeys.includes(getElementKey(element))
	});
</script>

{#each elements as element (getElementKey(element))}
	{@render children?.({ element, isSelected: selectedElements.includes(element) })}
{/each}
