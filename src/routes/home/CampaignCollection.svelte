<script lang="ts" context="module">
</script>

<script lang="ts">
	import { goto } from '$app/navigation';
	import { accountState, Session } from 'client/state';
	import { Button, Text } from 'components';
	import ArrangedCollection from 'components/ArrangedCollection.svelte';
	import DragHandle from 'components/DragHandle.svelte';
	import { Column, Container, Placeholder, Row } from 'components/layout';
	import type { ModalContext } from 'components/modal';
	import type { CampaignCardSnippet, CampaignSnippet } from 'shared';
	import { getContext } from 'svelte';
	import Time from 'svelte-time/Time.svelte';
	import CampaignEditDialog from './CampaignEditDialog.svelte';

	let campaigns = [...($accountState?.campaigns ?? [])];

	const modal = getContext<ModalContext>('modal');

	async function editCampaign(unedited: CampaignCardSnippet) {
		const result: CampaignCardSnippet | undefined = await modal.display(CampaignEditDialog, {
			...unedited
		});

		if (result) {
			campaigns = campaigns.map((campaign) => (campaign === unedited ? result : campaign));
		}
	}

	async function createCampaign() {
		const result: CampaignSnippet | undefined = await modal.display(CampaignEditDialog, {
			name: ''
		});

		if (result) {
			goto('/games/' + result.id);
			Session.instance.campaign.onEnter(result);
		}
	}
</script>

<ArrangedCollection bind:items={campaigns} let:item={campaign} let:handle>
	<Container>
		<Row gap="big" align="center" justify="space-between">
			<h2>{campaign.name}</h2>
			<DragHandle {handle} />
		</Row>
		<Column gap="big">
			<Text style="subtitle">Created <Time timestamp={campaign.createdAt} /></Text>

			<Placeholder>Preview Image</Placeholder>

			<Row gap="normal">
				<Button on:click={() => editCampaign(campaign)}>Settings</Button>
				<Button highlight raised href="games/{campaign.id}">Host Session</Button>
			</Row>
		</Column>
	</Container>

	<svelte:fragment slot="plus">
		<Button raised on:click={createCampaign}>Create new campaign</Button>
	</svelte:fragment>
</ArrangedCollection>

<style>
	h2 {
		margin: 0;
	}
</style>
