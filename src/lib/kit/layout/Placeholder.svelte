<script lang="ts">
	export let expand = false;
</script>

<div class:expand>
	PLACEHOLDER
	{#if $$slots.default}
		<br />
		(<slot></slot>)
	{/if}
</div>

<style lang="scss">
	@function thin-line($direction) {
		@return linear-gradient(
			to $direction,
			transparent calc(50% - 1px),
			#fffa 50%,
			transparent calc(50% + 1px)
		);
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
