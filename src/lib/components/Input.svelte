<script lang="ts" module>
	export function focusOnMount(node: HTMLInputElement, enabled: boolean = true) {
		if (enabled) {
			node.focus();
		}
	}
</script>

<script lang="ts">
	import { run } from 'svelte/legacy';

	import type { HTMLInputTypeAttribute } from 'svelte/elements';

	interface Props {
		value: string | number;
		name: string;
		label?: string | undefined;
		id?: string | undefined;
		placeholder: string;
		type?: HTMLInputTypeAttribute | undefined;
		required?: boolean | undefined;
		autocomplete?: 'email' | 'current-password' | 'new-password' | undefined;
		autofocus?: boolean;
		size?: 'small' | undefined;
	}

	let {
		value = $bindable(),
		name,
		label = undefined,
		id = undefined,
		placeholder,
		type = undefined,
		required = undefined,
		autocomplete = undefined,
		autofocus = false,
		size = undefined
	}: Props = $props();

	function applyType(node: HTMLInputElement) {
		if (type !== undefined) {
			node.type = type;
		}

		if (autofocus) {
			node.focus();
		}
	}

	// "const" -> Only updated on mount
	const isNumericInput = typeof value === 'number';

	let valueAsString = $state(`${value}`);
	run(() => {
		if (isNumericInput) {
			value = parseFloat(valueAsString);
		} else {
			value = valueAsString;
		}
	});
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
			bind:value={valueAsString}
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
		bind:value={valueAsString}
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
