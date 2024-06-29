<script lang="ts">
	import Row from '$lib/kit/layout/Row.svelte';
	import { onMount } from 'svelte';

	import { Session } from '$lib/client/session';
	import { session } from '$lib/client/socket';
	import { socket } from '$lib/stores';
	import BoardView from './BoardView.svelte';
	import Sidebar from './Sidebar.svelte';

	onMount(async () => {
		const campaign = await $socket.request('campaignHost', { id: 't78kb' });

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
