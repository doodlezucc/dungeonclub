<script lang="ts">
	import { Campaign } from '$lib/client/state';
	import BoardView from '$lib/ui/game/BoardView.svelte';
	import Sidebar from '$lib/ui/game/Sidebar.svelte';
	import { Row } from 'packages/ui';
	import { onMount } from 'svelte';
	import type { PageProps } from './$types';

	let { params }: PageProps = $props();

	onMount(async () => {
		await Campaign.instance.join({ id: params.campaignId });
	});
</script>

<main class="column expand">
	<Row expand>
		<BoardView />
		<Sidebar />
	</Row>
</main>

<style>
	main {
		padding: 0;
	}
</style>
