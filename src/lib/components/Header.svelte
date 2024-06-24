<script>
	import Content from './Content.svelte';
</script>

<header>
	<Content>
		<h1>Dungeon Club</h1>
	</Content>
</header>

<style>
	header {
		background-color: var(--color-dark);
		padding: 1em 0;
		border-bottom: 3px solid var(--color-light);
	}

	h1 {
		margin: 0;
		font-size: 1.5em;
		color: var(--color-primary);
	}
</style>
