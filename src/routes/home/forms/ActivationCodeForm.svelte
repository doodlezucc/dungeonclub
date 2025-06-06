<script lang="ts">
	import { focusOnMount } from 'packages/ui/Input.svelte';
	import type { Snippet } from 'svelte';
	import Form from './Form.svelte';

	interface Props {
		title: string;
		submitButtonLabel?: string;
		handleCodeSubmit: (enteredCode: string) => Promise<void>;
		note?: Snippet;
	}

	let {
		title,
		submitButtonLabel = 'Verify',
		handleCodeSubmit,
		note: noteSnippet
	}: Props = $props();

	let enteredCode = $state('');
</script>

<Form
	{title}
	{submitButtonLabel}
	disableFormSpacing
	handleSubmit={() => handleCodeSubmit(enteredCode)}
>
	{#snippet note()}
		<p>
			{@render noteSnippet?.()}
		</p>
	{/snippet}

	<input name="activation-code" placeholder="CODE" bind:value={enteredCode} use:focusOnMount />
</Form>

<style>
	p {
		text-align: center;
		color: var(--color-text-pale);
		max-width: 20em;
	}

	input {
		min-width: 7em;
		width: 7em;
		text-align: center;
		font-size: 1.5em;
	}
</style>
