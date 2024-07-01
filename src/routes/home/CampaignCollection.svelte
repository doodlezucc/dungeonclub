<script lang="ts" context="module">
</script>

<script lang="ts">
	import { goto } from '$app/navigation';
	import { account, session, Session } from '$lib/client/state';
	import type { CampaignCardSnippet, CampaignSnippet } from '$lib/net/snippets/campaign';
	import { Button, Collection, IconButton, Text } from 'components';
	import { Center, Column, Container, Row } from 'components/layout';
	import type { ModalContext } from 'components/modal';
	import { getContext } from 'svelte';
	import Time from 'svelte-time/Time.svelte';
	import CampaignEditDialog from './CampaignEditDialog.svelte';

	$: campaigns = $account?.campaigns ?? [];

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
			$session = new Session(result);
		}
	}
</script>

<Collection items={campaigns} let:item={campaign}>
	<Container>
		<Row gap="big" align="center" justify="space-between">
			<h2>{campaign.name}</h2>
			<IconButton label="Edit Campaign" on:click={() => editCampaign(campaign)} icon="cog" />
		</Row>
		<Column gap="big">
			<Text style="subtitle">Created <Time timestamp={campaign.createdAt} /></Text>

			<Center>
				<Button highlight raised href="games/{campaign.id}">Host Session</Button>
			</Center>
		</Column>
	</Container>

	<svelte:fragment slot="plus">
		<Button raised on:click={createCampaign}>Create new campaign</Button>
	</svelte:fragment>
</Collection>

<style>
	h2 {
		margin: 0;
	}
</style>
