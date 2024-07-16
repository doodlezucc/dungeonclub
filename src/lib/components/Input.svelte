<script lang="ts">
	import type { HTMLInputTypeAttribute } from 'svelte/elements';

	export let value: string | number;

	export let name: string;
	export let label: string | undefined = undefined;
	export let id: string | undefined = undefined;

	export let placeholder: string;

	export let type: HTMLInputTypeAttribute | undefined = undefined;
	export let required: boolean | undefined = undefined;
	export let autocomplete: 'email' | 'current-password' | 'new-password' | undefined = undefined;
	export let autofocus: boolean | undefined = undefined;

	function applyTypeAndAutoFocus(node: HTMLInputElement) {
		if (type !== undefined) {
			node.type = type;
		}

		if (autofocus) {
			node.focus();
		}
	}
</script>

{#if label}
	<label>
		{label}

		<input
			{id}
			{name}
			{placeholder}
			{autocomplete}
			tabindex={autofocus ? 0 : undefined}
			{required}
			aria-required={required}
			bind:value
			use:applyTypeAndAutoFocus
		/>
	</label>
{:else}
	<input
		{id}
		{name}
		{placeholder}
		{autocomplete}
		tabindex={autofocus ? 0 : undefined}
		{required}
		aria-required={required}
		bind:value
		use:applyTypeAndAutoFocus
	/>
{/if}

<style>
	label {
		text-align: start;
		display: grid;
		gap: 0.25em;
	}
</style>
