<script lang="ts" context="module">
	export const TOAST_DURATION_MS = 2000;

	export interface ToastOptions {
		text: string;
		icon?: IconID;
	}
</script>

<script lang="ts">
	import Icon, { type IconID } from 'components/Icon.svelte';
	import Separator from 'components/layout/Separator.svelte';
	import Text from '../Text.svelte';

	export let options: ToastOptions;
</script>

<div class="toast">
	{#if options.icon}
		<Icon icon={options.icon} />
		<Separator />
	{/if}
	<Text>{options.text}</Text>
</div>

<style>
	.toast {
		display: flex;
		flex-direction: row;
		align-items: center;
		gap: 1em;
		border-radius: 50px;
		padding: 1em 1.5em;
		box-sizing: border-box;
		background-color: var(--color-container);
	}

	:global(.toast > *) {
		margin: 0;
	}

	:global(.toast > .separator) {
		height: 1em;
	}
</style>
