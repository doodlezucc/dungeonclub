<script lang="ts">
	import Board from '$lib/components/session/Board.svelte';
	import Sidebar from '$lib/components/session/Sidebar.svelte';
	import Row from '$lib/kit/layout/Row.svelte';

	export let data;
</script>

<main class="column expand">
	<h2>Session with game ID "{data.id}"</h2>

	<Row expand>
		<Board />
		<Sidebar />
	</Row>
</main>
