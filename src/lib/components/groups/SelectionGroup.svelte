<script lang="ts" context="module">
	export interface SelectOptions {
		additive: boolean;
	}

	export interface SelectionContext<T> {
		select(element: T, options: SelectOptions): void;

		forEach(action: (element: T) => void): void;
		map<B>(transform: (element: T) => B): B[];
		includes(element: T): boolean;
	}
</script>

<script lang="ts" generics="T">
	import { setContext } from 'svelte';

	export let elements: T[];
	export let toKey: (element: T) => string;

	$: selectedKeys = [] as string[];
	$: selectedElements = elements.filter((element) => selectedKeys.includes(toKey(element)));

	setContext<SelectionContext<T>>('selection', {
		select: (element, { additive }) => {
			const key = toKey(element);

			if (additive) {
				if (!selectedKeys.includes(key)) {
					selectedKeys = [...selectedKeys, key];
				}
			} else {
				selectedKeys = [key];
			}
		},
		forEach: (action) => {
			for (const element of selectedElements) {
				action(element);
			}
		},
		map: (transform) => selectedElements.map(transform),
		includes: (element) => selectedKeys.includes(toKey(element))
	});
</script>

{#each elements as element (toKey(element))}
	<slot {element} isSelected={selectedElements.includes(element)} />
{/each}
