<script lang="ts">
	import Row from '$lib/kit/layout/Row.svelte';
	import { onMount } from 'svelte';

	import { Session } from '$lib/client/session';
	import { session } from '$lib/client/socket';
	import BoardView from './BoardView.svelte';
	import Sidebar from './Sidebar.svelte';

	export let data;

	$: campaign = data.campaign;

	onMount(() => {
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
