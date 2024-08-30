<script lang="ts">
	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { boardState, campaignState } from 'client/state';
	import { listenTo, ShortcutAction } from 'components/extensions/ShortcutListener.svelte';
	import SelectionGroup from 'components/groups/SelectionGroup.svelte';
	import type { TokenSnippet } from 'shared';
	import { getContext } from 'svelte';
	import { derived } from 'svelte/store';
	import { type BoardContext } from './Board.svelte';
	import Token from './tokens/Token.svelte';
	import UnplacedToken, {
		unplacedTokenProperties,
		type TokenPlacementEvent
	} from './tokens/UnplacedToken.svelte';
	import * as Tokens from './tokens/token-management';

	const loadedBoardId = derived(boardState, (board) => board!.id);

	$: tokens = $boardState!.tokens;
	$: tokenTemplates = $campaignState!.templates;

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

	export function clearSelection() {
		tokenSelectionGroup?.clear();
	}

	function buildContextForTokenManagement(): Tokens.Context {
		return {
			boardHistory: historyOf($loadedBoardId),
			socket: $socket
		};
	}

	function onPlaceToken(ev: CustomEvent<TokenPlacementEvent>) {
		Tokens.createNewToken(
			{
				position: ev.detail.position,
				tokenTemplateId: ev.detail.templateId ?? null,
				onServerSideCreation: (instantiatedToken) => {
					tokenSelectionGroup!.select(instantiatedToken, { additive: false });
				}
			},
			buildContextForTokenManagement()
		);
	}

	const onPressDelete = listenTo(ShortcutAction.Delete);
	$onPressDelete.handle(() => {
		const selectedTokens = tokenSelectionGroup?.getSelectedElements() ?? [];

		if (selectedTokens.length > 0) {
			Tokens.deleteTokens(selectedTokens, buildContextForTokenManagement());
		}
	});
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
	{#key $unplacedTokenProperties.tokenTemplate?.id}
		<UnplacedToken
			template={$unplacedTokenProperties.tokenTemplate}
			spawnPosition={unplacedTokenSpawnPosition}
			on:place={onPlaceToken}
		/>
	{/key}
{/if}
