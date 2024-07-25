<script lang="ts">
	import { asset } from 'client/communication/asset';
	import { tooltip } from 'components/modal/tooltip';
	import type { TokenTemplateSnippet } from 'shared';

	export let template: TokenTemplateSnippet;

	$: avatarSrc = asset(template.avatar!.path);

	function handleClick() {
		console.log('click');
	}

	function handleKeyDown(ev: KeyboardEvent) {}
</script>

<div
	role="button"
	class="token-template custom"
	tabindex="0"
	on:keydown={handleKeyDown}
	on:click={handleClick}
	use:tooltip={{ label: 'Le Token' }}
>
	<img src={avatarSrc} alt="T" title={template.name} />
</div>

<style>
	.token-template {
		width: 100%;
		height: 100%;
		border: 1px solid var(--color-separator);
		box-sizing: border-box;
	}

	img {
		width: 100%;
		height: 100%;
	}
</style>
