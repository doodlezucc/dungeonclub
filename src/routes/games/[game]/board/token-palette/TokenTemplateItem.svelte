<script lang="ts">
	import { asset } from 'client/communication/asset';
	import { Row } from 'components/layout';
	import ListTile from 'components/ListTile.svelte';
	import type { TokenTemplateSnippet } from 'shared';
	import { unplacedToken } from '../Board.svelte';

	export let template: TokenTemplateSnippet;

	$: avatarSrc = asset(template.avatar!.path);

	$: captureMouseMovement = false;

	function handleMouseDown(ev: MouseEvent) {
		ev.preventDefault();
		captureMouseMovement = true;
	}

	function displayTokenAtCursor(ev: MouseEvent) {
		ev.preventDefault();

		captureMouseMovement = false;
		$unplacedToken = {
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
	<Row align="center" gap="normal">
		<img class="token-template-avatar" src={avatarSrc} alt="Token avatar" />
		<span>{template.name}</span>
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
