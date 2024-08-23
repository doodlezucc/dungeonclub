<script lang="ts">
	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { Board, boardState, sessionState } from 'client/state';
	import { listenTo, ShortcutAction } from 'components/extensions/ShortcutListener.svelte';
	import SelectionGroup from 'components/groups/SelectionGroup.svelte';
	import type { TokenSnippet } from 'shared';
	import { getContext } from 'svelte';
	import { derived } from 'svelte/store';
	import { type BoardContext } from './Board.svelte';
	import Token from './tokens/Token.svelte';
	import UnplacedToken, { unplacedTokenProperties } from './tokens/UnplacedToken.svelte';

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

	const onPressDelete = listenTo(ShortcutAction.Delete);
	$onPressDelete.handle(() => {
		const selectedTokens = tokenSelectionGroup?.getSelectedElements() ?? [];

		if (selectedTokens.length > 0) {
			const actionName =
				selectedTokens.length === 1 ? 'Remove token from board' : 'Remove tokens from board';

			const selectedTokenIds = selectedTokens.map((token) => token.id);

			historyOf($loadedBoardId).registerUndoable(actionName, async () => {
				$socket.send('tokensDelete', {
					tokenIds: selectedTokenIds
				});

				Board.instance.handleTokensDelete({ tokenIds: selectedTokenIds });

				return {
					undo: () => {
						$socket.send('tokensRestore', {
							tokenIds: selectedTokenIds
						});
					}
				};
			});
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
			on:instantiate={onCreateNewToken}
		/>
	{/key}
{/if}
