<script lang="ts">
	import type { Snippet } from 'svelte';
	import { fly } from 'svelte/transition';

	interface Props {
		showActivationCodeForm: boolean;
		credentialsForm: Snippet;
		codeForm: Snippet;
	}

	let { showActivationCodeForm, credentialsForm, codeForm }: Props = $props();
</script>

<main>
	{#if !showActivationCodeForm}
		<div out:fly={{ x: -100 }}>
			{@render credentialsForm()}
		</div>
	{:else}
		<div in:fly={{ x: 100, delay: 400 }}>
			{@render codeForm()}
		</div>
	{/if}
</main>

<style>
	main {
		display: grid;
		justify-items: center;
	}

	main > div {
		position: absolute;
	}
</style>
