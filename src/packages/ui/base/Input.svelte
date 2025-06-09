<script lang="ts" module>
	export function focusOnMount(node: HTMLInputElement, enabled: boolean = true) {
		if (enabled) {
			node.focus();
		}
	}
</script>

<script lang="ts">
	import type { HTMLInputAttributes, HTMLInputTypeAttribute } from 'svelte/elements';

	interface Props {
		value: string | number;
		name: string;
		label?: string;
		id?: string;
		placeholder: string;
		type?: HTMLInputTypeAttribute;
		required?: boolean;
		autocomplete?: 'email' | 'current-password' | 'new-password';
		autofocus?: boolean;
		size?: 'small';

		onInput?: HTMLInputAttributes['oninput'];
	}

	let {
		value = $bindable(),
		name,
		label,
		id,
		placeholder,
		type,
		required,
		autocomplete,
		autofocus = false,
		size,
		onInput
	}: Props = $props();

	function applyType(node: HTMLInputElement) {
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
			data-size={size}
			bind:value
			oninput={onInput}
			use:applyType
			use:focusOnMount={autofocus}
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
		data-size={size}
		bind:value
		oninput={onInput}
		use:applyType
		use:focusOnMount={autofocus}
	/>
{/if}

<style>
	label {
		text-align: start;
		display: grid;
		gap: 0.25em;
	}

	input[data-size='small'] {
		min-width: 0;
	}
</style>
