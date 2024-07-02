<script lang="ts">
	import { onMount } from 'svelte';

	import { page } from '$app/stores';
	import { socket } from '$lib/client/communication';
	import { session, Session } from '$lib/client/state';
	import { Row } from 'components/layout';
	import BoardView from './BoardView.svelte';
	import Sidebar from './Sidebar.svelte';

	onMount(async () => {
		const campaign = await $socket.request('campaignJoin', { id: $page.params.game });

		if (campaign) {
			$session = new Session(campaign);
		}
	});
</script>

<main class="column expand">
	<Row expand>
		<BoardView />
		<Sidebar />
	</Row>
</main>
