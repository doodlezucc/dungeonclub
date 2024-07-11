<script lang="ts">
	import { onMount } from 'svelte';

	import { page } from '$app/stores';
	import { Session } from 'client/state';
	import { Row } from 'components/layout';
	import BoardView from './BoardView.svelte';
	import Sidebar from './Sidebar.svelte';

	onMount(async () => {
		await Session.instance.campaign.join({ id: $page.params.game });
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
