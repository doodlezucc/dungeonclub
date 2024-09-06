<script lang="ts">
	import IconButton from 'components/IconButton.svelte';
	import Row from 'components/layout/Row.svelte';

	export let isInheriting: boolean;

	function toggle() {
		isInheriting = !isInheriting;
	}
</script>

<Row gap="big" align="center">
	<slot />

	<span class:is-inheriting={isInheriting}>
		<IconButton
			icon={isInheriting ? 'link' : 'link-slash'}
			label={isInheriting ? 'Make unique' : 'Inherit from template'}
			size="small"
			disableMargin
			on:click={toggle}
		/>
	</span>
</Row>

<style>
	span:not(.is-inheriting):not(:hover, :active) {
		opacity: 0.5;
	}

	span.is-inheriting {
		color: var(--color-primary);
	}
</style>
