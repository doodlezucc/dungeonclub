<script lang="ts" context="module">
</script>

<script lang="ts">
	import { goto } from '$app/navigation';
	import { Session } from '$lib/client/session';
	import { account, session } from '$lib/client/socket';
	import type { ICampaign } from '$lib/db/schemas';
	import Button from '$lib/kit/Button.svelte';
	import Collection from '$lib/kit/Collection.svelte';
	import IconButton from '$lib/kit/IconButton.svelte';
	import Center from '$lib/kit/layout/Center.svelte';
	import Column from '$lib/kit/layout/Column.svelte';
	import Container from '$lib/kit/layout/Container.svelte';
	import Row from '$lib/kit/layout/Row.svelte';
	import type { ModalContext } from '$lib/kit/ModalProvider.svelte';
	import Text from '$lib/kit/Text.svelte';
	import type { CampaignCardSnippet } from '$lib/net/snippets/campaign';
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
		const result: ICampaign | undefined = await modal.display(CampaignEditDialog, {
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
