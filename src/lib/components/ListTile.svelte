<script lang="ts">
</script>

<li class="list-tile">
	<div role="button" class="token-template custom" tabindex="0" on:keydown on:click on:mousedown>
		<slot />
	</div>
</li>

<style>
	li {
		display: flex;
	}

	div {
		display: flex;
		cursor: default;
		flex: 1;
	}
</style>
