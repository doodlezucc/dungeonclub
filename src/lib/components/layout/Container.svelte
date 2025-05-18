<script lang="ts" module>
	export type Padding = 'big';
	export type ContainerMargin = 'big';

	export type ContainerVariant = 'elevated' | 'outlined';
</script>

<script lang="ts">

	interface Props {
		margin?: ContainerMargin | undefined;
		padding?: Padding | undefined;
		variant?: ContainerVariant;
		children?: import('svelte').Snippet;
	}

	let {
		margin = undefined,
		padding = undefined,
		variant = 'elevated',
		children
	}: Props = $props();
</script>

<div class="container" data-margin={margin} data-padding={padding} data-variant={variant}>
	{@render children?.()}
</div>
