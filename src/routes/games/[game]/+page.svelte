<script lang="ts">
	import BoardView from '$lib/components/session/BoardView.svelte';
	import Sidebar from '$lib/components/session/Sidebar.svelte';
	import Row from '$lib/kit/layout/Row.svelte';
	import { setContext } from 'svelte';

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
