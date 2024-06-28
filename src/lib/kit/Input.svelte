<script lang="ts">
	import type { HTMLInputTypeAttribute } from 'svelte/elements';

	export let value: string | number;

	export let name: string;
	export let label: string;

	export let type: HTMLInputTypeAttribute | undefined = undefined;
	export let required: boolean | undefined = undefined;
	export let autocomplete: 'email' | 'current-password' | 'new-password' | undefined = undefined;

	function applyType(node: HTMLInputElement) {
		if (type !== undefined) {
			node.type = type;
		}
	}
</script>

<label>
	{label}
	<input {name} {autocomplete} {required} aria-required={required} bind:value use:applyType />
</label>

<style>
	label {
		display: grid;
		gap: 0.25em;
	}
</style>
