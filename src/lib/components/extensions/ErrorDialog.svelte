<script lang="ts">
	import { getContext } from 'svelte';
	import { Button, Text } from '..';
	import { Dialog, type ModalContext } from '../modal';

	interface Props {
		error: unknown;
	}

	let { error }: Props = $props();

	const modal = getContext<ModalContext>('modal');
</script>

<Dialog title="Error :(">
	<Text>Sincere apologies! An error occurred.</Text>
	<Text style="code" color="error">{error}</Text>

	{#snippet actions()}
	
			<Button raised on:click={() => modal.pop()}>OK</Button>
		
	{/snippet}
</Dialog>
