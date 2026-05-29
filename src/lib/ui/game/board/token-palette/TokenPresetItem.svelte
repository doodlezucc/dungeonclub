<script lang="ts">
	import { asset } from '$lib/client/communication/asset';
	import { Campaign } from '$lib/client/state';
	import type { TokenPresetSnippet } from '$lib/net';
	import { Flex, IconButton, ListTile, Row } from 'packages/ui';
	import { unplacedTokenProperties } from '../tokens/UnplacedToken.svelte';

	interface Props {
		preset: TokenPresetSnippet;

		handleDelete: () => void;
	}

	let { preset, handleDelete }: Props = $props();

	let avatarAsset = $derived(Campaign.instance.assetByNullableId(preset.avatarId));
	let avatarSrc = $derived($avatarAsset ? asset($avatarAsset.path) : null);

	let isSelectedForPlacement = $derived($unplacedTokenProperties?.tokenPreset === preset);

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
			tokenPreset: preset,
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
		<img class="token-preset-avatar" src={avatarSrc} alt="Token avatar" />
		<span>{preset.name}</span>

		<Flex expand />

		<IconButton label="Delete" icon="remove" onclick={handleDelete} />
	</Row>
</ListTile>

<style lang="scss">
	$avatar-size: 40px;

	.token-preset-avatar {
		width: $avatar-size;
		height: $avatar-size;
		border-radius: 50%;
		padding: 0;
		object-fit: cover;
	}
</style>
