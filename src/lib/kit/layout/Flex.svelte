<script lang="ts" context="module">
	export type FlexDirection = 'column' | 'row';
	export type Gap = 'normal';

	export type FlexAlign = 'start' | 'center' | 'end';
	export type FlexJustify =
		| 'start'
		| 'center'
		| 'end'
		| 'space-between'
		| 'space-around'
		| 'space-evenly';
</script>

<script lang="ts">
	export let direction: FlexDirection | undefined = undefined;
	export let gap: Gap | undefined = undefined;

	export let align: FlexAlign | undefined = undefined;
	export let justify: FlexJustify | undefined = undefined;

	export let expand = false;
</script>

<div
	class={direction}
	class:gap-normal={gap === 'normal'}
	class:expand
	data-align={align}
	data-justify={justify}
>
	<slot />
</div>

<style>
	.gap-normal {
		gap: 0.3em;
	}

	[data-align='start'] {
		align-items: flex-start;
	}
	[data-align='center'] {
		align-items: center;
	}
	[data-align='end'] {
		align-items: flex-end;
	}

	[data-justify='start'] {
		justify-content: flex-start;
	}
	[data-justify='center'] {
		justify-content: center;
	}
	[data-justify='end'] {
		justify-content: flex-end;
	}
	[data-justify='space-between'] {
		justify-content: space-between;
	}
	[data-justify='space-around'] {
		justify-content: space-around;
	}
	[data-justify='space-evenly'] {
		justify-content: space-evenly;
	}
</style>
