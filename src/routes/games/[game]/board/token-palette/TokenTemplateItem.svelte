<script lang="ts">
	import Row from 'components/layout/Row.svelte';
	import type { TokenTemplateSnippet } from 'shared';

	export let template: TokenTemplateSnippet;

	$: displayName = template.name.length > 0 ? template.name : '(Untitled)';
</script>

<li class="row token-template">
	<Row gap="normal" align="center">
		<img alt="Avatar" />
		<span>
			{displayName}
		</span>
	</Row>
</li>

<style>
	li {
		background-color: var(--color-background);
	}

	img {
		width: 48px;
		height: 48px;
	}
</style>
