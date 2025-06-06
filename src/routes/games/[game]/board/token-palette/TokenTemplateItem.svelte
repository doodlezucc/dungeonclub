<script lang="ts">
	import { asset } from '$lib/client/communication/asset';
	import { Campaign } from '$lib/client/state';
	import IconButton from 'packages/ui/IconButton.svelte';
	import { Flex, Row } from 'packages/ui/layout';
	import ListTile from 'packages/ui/ListTile.svelte';
	import type { TokenTemplateSnippet } from 'shared';
	import { unplacedTokenProperties } from '../tokens/UnplacedToken.svelte';

	interface Props {
		template: TokenTemplateSnippet;

		handleDelete: () => void;
	}

	let { template, handleDelete }: Props = $props();

	let avatarAsset = $derived(Campaign.instance.assetByNullableId(template.avatarId));
	let avatarSrc = $derived($avatarAsset ? asset($avatarAsset.path) : null);

	let isSelectedForPlacement = $derived($unplacedTokenProperties?.tokenTemplate === template);

	let captureMouseMovement = $state(false);

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
	onmousemove={captureMouseMovement ? displayTokenAtCursor : undefined}
	onmouseup={captureMouseMovement ? handleMouseUp : undefined}
/>

<ListTile
	selected={isSelectedForPlacement}
	onmousedown={handleMouseDown}
	onclick={displayTokenAtCursor}
>
	<Row align="center" gap="normal" expand>
		<img class="token-template-avatar" src={avatarSrc} alt="Token avatar" />
		<span>{template.name}</span>

		<Flex expand />

		<IconButton label="Delete" icon="remove" onclick={handleDelete} />
	</Row>
</ListTile>

<style lang="scss">
	$avatar-size: 40px;

	.token-template-avatar {
		width: $avatar-size;
		height: $avatar-size;
		border-radius: 50%;
		padding: 0;
		object-fit: cover;
	}
</style>
