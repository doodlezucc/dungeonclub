<script lang="ts">
	import Row from '$lib/kit/layout/Row.svelte';

	import { setContext } from 'svelte';

	import BoardView from './BoardView.svelte';
	import Sidebar from './Sidebar.svelte';

	export let data;

	setContext('session', {
		campaign: data.campaign
	});
</script>

<main class="column expand">
	<Row expand>
		<BoardView />
		<Sidebar />
	</Row>
</main>
