<script lang="ts">
	import { Button, Text } from 'packages/ui';
	import { Dialog, type ModalContext } from 'packages/ui/modal';
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
