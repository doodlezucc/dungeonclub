<script lang="ts">
	interface Props {
		fat?: boolean;
	}

	let { fat = false }: Props = $props();
</script>

<div class="separator" class:fat></div>

<style>
	.separator {
		min-width: 1px;
		min-height: 1px;
		background-color: var(--color-separator);
	}

	.separator.fat {
		min-width: 2px;
		min-height: 2px;
	}
</style>
