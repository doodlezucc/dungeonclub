<script lang="ts">
	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { Board, boardState, sessionState } from 'client/state';
	import { writableReferenceTo } from 'client/state/reference';
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
			const tokenReferences = selectedTokens.map((token) => writableReferenceTo(token.id));

			historyOf($loadedBoardId).registerUndoable(actionName, async () => {
				const deletedTokenIds = tokenReferences.map((tokenReference) => tokenReference.resolve());
				const deletedTokens = $boardState!.tokens.filter((token) =>
					deletedTokenIds.includes(token.id)
				);

				$socket.send('tokensDelete', { tokenIds: deletedTokenIds });
				Board.instance.handleTokensDelete({ tokenIds: deletedTokenIds });

				for (const reference of tokenReferences) {
					reference.clear();
				}

				return {
					undo: async () => {
						const response = await $socket.request('tokensCreate', {
							newTokens: deletedTokens.map((deletedToken) => ({
								templateId: deletedToken.templateId,
								x: deletedToken.x,
								y: deletedToken.y,
								conditions: deletedToken.conditions,
								invisible: deletedToken.invisible,
								label: deletedToken.label,
								size: deletedToken.size
							}))
						});
						Board.instance.handleTokensCreate(response);

						for (let i = 0; i < tokenReferences.length; i++) {
							tokenReferences[i].set(response.tokens[i].id);
						}
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
