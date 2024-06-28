<script lang="ts">
	import { account } from '$lib/client/socket';
	import Row from '$lib/kit/layout/Row.svelte';
	import Text from '$lib/kit/Text.svelte';
	import { flip } from 'svelte/animate';
	import { fly } from 'svelte/transition';
	import CampaignCard from './CampaignCard.svelte';

	$: campaigns = $account?.campaigns ?? [];
</script>

<Text style="display">Your Campaigns</Text>

<Row gap="normal" wrap>
	{#each campaigns as campaign, index (campaign.id)}
		<div animate:flip in:fly|global={{ y: 30, delay: 200 + index * 50 }}>
			<CampaignCard bind:snippet={campaign} />
		</div>
	{/each}
</Row>
