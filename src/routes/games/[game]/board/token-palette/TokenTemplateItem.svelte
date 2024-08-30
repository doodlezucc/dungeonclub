<script lang="ts">
	import { asset } from 'client/communication/asset';
	import IconButton from 'components/IconButton.svelte';
	import { Flex, Row } from 'components/layout';
	import ListTile from 'components/ListTile.svelte';
	import type { TokenTemplateSnippet } from 'shared';
	import { createEventDispatcher } from 'svelte';
	import { unplacedTokenProperties } from '../tokens/UnplacedToken.svelte';

	export let template: TokenTemplateSnippet;
	const avatarSrc = template.avatar ? asset(template.avatar!.path) : null;

	const dispatch = createEventDispatcher<{
		delete: void;
	}>();

	let captureMouseMovement = false;

	function handleMouseDown(ev: MouseEvent) {
		if (ev.target instanceof HTMLButtonElement) {
			return;
		}

		ev.preventDefault();
		captureMouseMovement = true;
	}

	function displayTokenAtCursor(ev: MouseEvent) {
		ev.preventDefault();

		captureMouseMovement = false;
		$unplacedTokenProperties = {
			tokenTemplate: template,
			triggeringEvent: ev
		};
	}

	function handleMouseUp() {
		captureMouseMovement = false;
	}
</script>

<svelte:window
	on:mousemove={captureMouseMovement ? displayTokenAtCursor : undefined}
	on:mouseup={captureMouseMovement ? handleMouseUp : undefined}
/>

<ListTile on:mousedown={handleMouseDown} on:click={displayTokenAtCursor}>
	<Row align="center" gap="normal" expand>
		<img class="token-template-avatar" src={avatarSrc} alt="Token avatar" />
		<span>{template.name}</span>
		<Flex expand />
		<IconButton label="Delete" icon="trash" on:click={() => dispatch('delete')} />
	</Row>
</ListTile>

<style lang="scss">
	$avatar-size: 40px;

	.token-template-avatar {
		width: $avatar-size;
		height: $avatar-size;
		border-radius: 50%;
		padding: 0;
	}
</style>
