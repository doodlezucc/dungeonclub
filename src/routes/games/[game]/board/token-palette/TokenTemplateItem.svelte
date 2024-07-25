<script lang="ts">
	import { asset } from 'client/communication/asset';
	import { Row } from 'components/layout';
	import ListTile from 'components/ListTile.svelte';
	import type { TokenTemplateSnippet } from 'shared';

	export let template: TokenTemplateSnippet;

	$: avatarSrc = asset(template.avatar!.path);

	function handleMouseDown(ev: MouseEvent) {
		ev.preventDefault();
		console.log('click');
	}
</script>

<ListTile on:mousedown={handleMouseDown}>
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
