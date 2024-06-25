<script>
	import Container from './Container.svelte';

	export let expand = false;
</script>

<div class:expand>PLACEHOLDER</div>

<style lang="scss">
	@function thin-line($direction) {
		@return linear-gradient(to $direction, transparent 49.9%, #fffa 50%, transparent 50.1%);
	}

	div {
		background: thin-line(left bottom), thin-line(right bottom);
		outline: 2px dashed white;
		outline-offset: 2px;
		margin: 6px;
		padding: 2em;

		display: flex;
		text-align: center;
		align-items: center;
		justify-content: center;
	}
</style>
