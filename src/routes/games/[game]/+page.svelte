<script lang="ts">
	import { onMount } from 'svelte';

	import { page } from '$app/state';
	import { Campaign } from '$lib/client/state';
	import BoardView from '$lib/ui/game/BoardView.svelte';
	import Sidebar from '$lib/ui/game/Sidebar.svelte';
	import { Row } from 'packages/ui';

	onMount(async () => {
		await Campaign.instance.join({ id: page.params.game });
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
