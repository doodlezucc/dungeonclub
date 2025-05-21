<script lang="ts">
	import { socket } from 'client/communication';
	import { Account } from 'client/state';
	import { Button, Input } from 'components';
	import { runWithErrorDialogBoundary } from 'components/extensions/modal';
	import { Flex } from 'components/layout';
	import { Dialog, type ModalContext } from 'components/modal';
	import { getContext } from 'svelte';
	import CampaignDeleteDialog from './CampaignDeleteDialog.svelte';

	interface Props {
		id?: string | undefined;
		name: string;
	}

	let { id = undefined, name = $bindable() }: Props = $props();

	const modal = getContext<ModalContext>('modal');

	async function save() {
		await runWithErrorDialogBoundary(modal, async () => {
			const commonSettings = {
				name,
				playerCharacters: []
			};

			let result;
			if (id) {
				result = await $socket.request('campaignEdit', {
					id: id,
					...commonSettings
				});
			} else {
				result = await $socket.request('campaignCreate', commonSettings);
			}

			modal.pop(result);
		});
	}

	async function deleteCampaign() {
		const confirmDeletion: boolean = await modal.display(CampaignDeleteDialog, {
			campaignName: name
		});

		if (confirmDeletion) {
			await runWithErrorDialogBoundary(modal, async () => {
				await $socket.request('campaignDelete', { id: id! });

				modal.pop();

				Account.campaigns.update((campaigns) => campaigns.filter((campaign) => campaign.id !== id));
			});
		}
	}
</script>

<Dialog title="Edit Campaign">
	<Input label="Campaign Name" name="Campaign Name" placeholder="Name..." bind:value={name} />

	{#snippet actions()}
		{#if id}
			<Button raised onclick={deleteCampaign}>
				<span class="error">Delete</span>
			</Button>
			<Flex expand />
		{/if}

		<Button type="submit" raised highlight onclick={save}>
			{id ? 'Save' : 'Create'}
		</Button>
	{/snippet}
</Dialog>
