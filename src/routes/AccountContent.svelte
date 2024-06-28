<script lang="ts">
	import Row from '$lib/kit/layout/Row.svelte';
	import { flip } from 'svelte/animate';
	import { fly } from 'svelte/transition';
	import CampaignCard from './CampaignCard.svelte';

	const campaigns = [
		{ id: 'testcampaign', name: 'My Test Campaign :)', createdAt: new Date() },
		{ id: 'testcampaign2', name: 'Second campaign', createdAt: new Date() },
		{ id: 'testcampaign3', name: 'Second campaign', createdAt: new Date() },
		{ id: 'testcampaign4', name: 'Second campaign', createdAt: new Date() },
		{ id: 'testcampaign5', name: 'Second campaign', createdAt: new Date() }
	];
</script>

<Row gap="normal" wrap>
	{#each campaigns as campaign, index (campaign.id)}
		<div animate:flip transition:fly|global={{ y: 30, delay: index * 50 }}>
			<CampaignCard {...campaign} />
		</div>
	{/each}
</Row>
