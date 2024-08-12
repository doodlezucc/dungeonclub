<script lang="ts">
	import { boardState, sessionState } from 'client/state';
	import SelectionGroup from 'components/groups/SelectionGroup.svelte';
	import type { TokenSnippet } from 'shared';
	import { derived } from 'svelte/store';
	import Token from './grid/Token.svelte';

	const loadedBoardId = derived(boardState, (board) => board!.id);

	$: tokens = $boardState!.tokens;
	$: tokenTemplates = $sessionState.campaign!.templates;

	$: tokenSelectionGroup = null as SelectionGroup<TokenSnippet> | null;

	$: {
		if ($loadedBoardId) {
			// Called whenever a board gets loaded
			tokenSelectionGroup?.clear();
		}
	}

	function getTemplateForToken(token: TokenSnippet) {
		return tokenTemplates.find((template) => template.id === token.templateId)!;
	}
</script>

<SelectionGroup
	bind:this={tokenSelectionGroup}
	elements={tokens}
	getElementKey={(token) => token.id}
	let:element
	let:isSelected
>
	<Token token={element} template={getTemplateForToken(element)} selected={isSelected} />
</SelectionGroup>
