<script lang="ts">
	import { getContext } from 'svelte';
	import Button from './Button.svelte';
	import Dialog from './Dialog.svelte';
	import type { ModalContext } from './ModalProvider.svelte';
	import Text from './Text.svelte';

	export let error: unknown;

	const modal = getContext<ModalContext>('modal');
</script>

<Dialog title="Error :(">
	<Text>Sincere apologies! An error occurred.</Text>
	<Text style="code" color="error">{error}</Text>

	<svelte:fragment slot="actions">
		<Button raised on:click={() => modal.pop()}>OK</Button>
	</svelte:fragment>
</Dialog>
