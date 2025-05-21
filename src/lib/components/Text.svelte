<script lang="ts" module>
	export type TextStyle = 'display' | 'heading' | 'subtitle' | 'body' | 'code';
	export type TextColor = 'error';

	export type TextStyleDefinition = {
		tag: string;
		className?: string;
	};

	export const textStyles: Record<TextStyle, TextStyleDefinition> = {
		display: {
			tag: 'h1'
		},
		heading: {
			tag: 'h2'
		},
		subtitle: {
			tag: 'span',
			className: 'subtitle'
		},
		body: {
			tag: 'p'
		},

		code: {
			tag: 'pre',

			className: 'code'
		}
	};
</script>

<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		style?: TextStyle;
		color?: TextColor | undefined;
		id?: string | undefined;
		children: Snippet;
	}

	let { style = 'body', color = undefined, id = undefined, children }: Props = $props();

	let styleDefinition = $derived(textStyles[style]);
</script>

<svelte:element
	this={styleDefinition.tag}
	class={styleDefinition.className}
	class:error={color === 'error'}
	{id}
>
	{@render children()}
</svelte:element>
