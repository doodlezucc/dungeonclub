<script lang="ts">
	import { boardState, sessionState } from 'client/state';
	import SelectionGroup from 'components/groups/SelectionGroup.svelte';
	import type { TokenSnippet } from 'shared';
	import { getContext } from 'svelte';
	import { derived } from 'svelte/store';
	import { type BoardContext } from './Board.svelte';
	import Token from './grid/Token.svelte';
	import UnplacedToken, { unplacedTokenProperties } from './grid/UnplacedToken.svelte';

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

	const board = getContext<BoardContext>('board');

	$: unplacedTokenSpawnPosition = $unplacedTokenProperties
		? board.transformClientToGridSpace({
				x: $unplacedTokenProperties.triggeringEvent.clientX,
				y: $unplacedTokenProperties.triggeringEvent.clientY
			})
		: null;

	function onCreateNewToken(event: CustomEvent<TokenSnippet>) {
		tokenSelectionGroup?.select(event.detail, { additive: false });
	}

	export function clearSelection() {
		tokenSelectionGroup?.clear();
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

{#if $unplacedTokenProperties && unplacedTokenSpawnPosition}
	{#key $unplacedTokenProperties.tokenTemplate.id}
		<UnplacedToken
			template={$unplacedTokenProperties.tokenTemplate}
			spawnPosition={unplacedTokenSpawnPosition}
			on:instantiate={onCreateNewToken}
		/>
	{/key}
{/if}
