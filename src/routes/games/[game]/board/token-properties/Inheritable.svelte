<script lang="ts">
	import IconButton from 'components/IconButton.svelte';
	import { Row } from 'components/layout';

	export let isInheriting: boolean;
	export let disableToggle: boolean = false;

	function toggle() {
		isInheriting = !isInheriting;
	}
</script>

<Row gap="big" align="center">
	<slot />

	<span class:is-inheriting={isInheriting} class:disabled={disableToggle}>
		<IconButton
			icon={isInheriting ? 'link' : 'link-slash'}
			label={isInheriting ? 'Make unique' : 'Inherit from template'}
			disabled={disableToggle}
			disableMargin
			inline
			on:click={toggle}
		/>
	</span>
</Row>

<style>
	span.disabled {
		opacity: 0.5;
	}
	span:not(.is-inheriting) {
		color: var(--color-text-pale);
	}

	span.is-inheriting {
		color: var(--color-primary);
	}
</style>
