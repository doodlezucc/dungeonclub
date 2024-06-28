<script lang="ts" context="module">
	export type TextStyle = 'heading' | 'subtitle' | 'body';

	export type TextStyleDefinition = {
		tag: string;
		className?: string;
	};

	export const textStyles: Record<TextStyle, TextStyleDefinition> = {
		heading: {
			tag: 'h2'
		},
		subtitle: {
			tag: 'span',
			className: 'subtitle'
		},
		body: {
			tag: 'p'
		}
	};
</script>

<script lang="ts">
	export let style: TextStyle = 'body';

	$: styleDefinition = textStyles[style];
</script>

<svelte:element this={styleDefinition.tag} class={styleDefinition.className}>
	<slot />
</svelte:element>
