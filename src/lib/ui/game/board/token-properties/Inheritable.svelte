<script lang="ts">
	import { Align, IconButton, Stack } from 'packages/ui';
	import type { Snippet } from 'svelte';

	interface Props {
		isInheriting: boolean;
		disableToggle?: boolean;
		children: Snippet;
	}

	let { isInheriting = $bindable(), disableToggle = false, children }: Props = $props();

	function toggle() {
		isInheriting = !isInheriting;
	}
</script>

<div class="property-container" class:is-inheriting={isInheriting}>
	<Stack>
		{@render children()}

		<Align alignment="right" margin="small">
			<span class:is-inheriting={isInheriting} class:disabled={disableToggle}>
				<IconButton
					icon={disableToggle ? 'link-slash' : isInheriting ? 'globe' : 'reply'}
					label={isInheriting ? 'Make unique' : 'Inherit from preset'}
					disabled={disableToggle}
					disableMargin
					inline
					onclick={toggle}
				/>
			</span>
		</Align>
	</Stack>
</div>

<style>
	.property-container.is-inheriting {
		color: var(--color-primary);
	}

	.property-container:not(:hover) span,
	span.disabled {
		opacity: 0.7;
	}

	span {
		transition-duration: 0.2s;
	}

	span:not(.is-inheriting) {
		color: var(--color-text-pale);
	}
</style>
