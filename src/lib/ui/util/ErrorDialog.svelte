<script lang="ts">
	import { Button, Dialog, Text, type ModalContext } from 'packages/ui';
	import { getContext } from 'svelte';

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
		<Button raised onclick={() => modal.pop()}>OK</Button>
	{/snippet}
</Dialog>
