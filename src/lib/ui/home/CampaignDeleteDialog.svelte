<script lang="ts">
	import { Button, Dialog, Text, type ModalContext } from 'packages/ui';
	import { getContext } from 'svelte';

	interface Props {
		campaignName: string;
	}

	let { campaignName }: Props = $props();

	const modal = getContext<ModalContext>('modal');
</script>

<Dialog title="Delete Campaign" disableCloseButton>
	<Text>
		Are you sure you want to delete "{campaignName}"?
		<br />
		All of its boards, tokens and assets will be lost.
	</Text>

	{#snippet actions()}
		<Button onclick={() => modal.pop(null)}>Cancel</Button>
		<Button raised onclick={() => modal.pop(true)} type="submit">
			<span class="error">Delete</span>
		</Button>
	{/snippet}
</Dialog>
