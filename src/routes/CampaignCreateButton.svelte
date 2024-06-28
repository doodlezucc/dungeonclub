<script lang="ts" context="module">
</script>

<script lang="ts">
	import { goto } from '$app/navigation';
	import type { ICampaign } from '$lib/db/schemas';
	import Button from '$lib/kit/Button.svelte';
	import type { ModalContext } from '$lib/kit/ModalProvider.svelte';
	import { socket } from '$lib/stores';
	import { getContext } from 'svelte';
	import CampaignEditDialog from './CampaignEditDialog.svelte';

	const modal = getContext<ModalContext>('modal');

	async function createCampaign() {
		const result: ICampaign | undefined = await modal.display(CampaignEditDialog, {
			name: ''
		});

		console.log('result', result);

		if (result) {
			goto('/games/' + result.id);
			$socket.enterSession(result);
		}
	}
</script>

<Button raised on:click={createCampaign}>Create new campaign</Button>
