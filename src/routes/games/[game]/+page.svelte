<script lang="ts">
	import Row from '$lib/kit/layout/Row.svelte';
	import { socket } from '$lib/stores';
	import { onMount } from 'svelte';

	import BoardView from './BoardView.svelte';
	import Sidebar from './Sidebar.svelte';

	export let data;

	$: campaign = data.campaign;

	onMount(() => {
		if (campaign) {
			$socket.enterSession(campaign);
		}
	});
</script>

<main class="column expand">
	<Row expand>
		<BoardView />
		<Sidebar />
	</Row>
</main>
