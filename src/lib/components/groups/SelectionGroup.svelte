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
	export let getElementKey: (element: T) => string;

	$: selectedKeys = [] as string[];
	$: selectedElements = elements.filter((element) => selectedKeys.includes(getElementKey(element)));

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
		select,
		forEach: (action) => {
			for (const element of selectedElements) {
				action(element);
			}
		},
		map: (transform) => selectedElements.map(transform),
		includes: (element) => selectedKeys.includes(getElementKey(element))
	});
</script>

{#each elements as element (getElementKey(element))}
	<slot {element} isSelected={selectedElements.includes(element)} />
{/each}
