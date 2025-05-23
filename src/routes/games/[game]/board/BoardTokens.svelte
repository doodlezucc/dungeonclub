<script lang="ts">
	import { run } from 'svelte/legacy';

	import { historyOf } from '$lib/packages/undo-redo/history';
	import { socket } from 'client/communication';
	import { boardState, campaignState } from 'client/state';
	import { listenTo } from 'components/extensions/ShortcutListener.svelte';
	import SelectionGroup from 'components/groups/SelectionGroup.svelte';
	import type { TokenSnippet } from 'shared';
	import { getTemplateForToken } from 'shared/token-materializing';
	import { getContext } from 'svelte';
	import { derived as legacyDerived } from 'svelte/store';
	import { type BoardContext } from './Board.svelte';
	import Token from './tokens/Token.svelte';
	import UnplacedToken, {
		exitTokenPlacement,
		unplacedTokenProperties,
		type TokenPlacementEvent
	} from './tokens/UnplacedToken.svelte';
	import * as Tokens from './tokens/token-management';

	const loadedBoardId = legacyDerived(boardState, (board) => board!.id);

	let tokens = $derived($boardState!.tokens);
	let tokenTemplates = $derived($campaignState!.templates);

	let tokenSelectionGroup = $state(null as SelectionGroup<TokenSnippet> | null);
	let selectedTokens = $state<TokenSnippet[]>([]);
	interface Props {
		selectedTokenIds?: string[];
	}

	let { selectedTokenIds = $bindable([]) }: Props = $props();

	run(() => {
		if ($loadedBoardId) {
			// Called whenever a board gets loaded
			tokenSelectionGroup?.clear();
		}
	});

	const board = getContext<BoardContext>('board');

	let unplacedTokenSpawnPosition = $derived(
		$unplacedTokenProperties
			? board.transformClientToGridSpace({
					x: $unplacedTokenProperties.triggeringEvent.clientX,
					y: $unplacedTokenProperties.triggeringEvent.clientY
				})
			: null
	);

	export function clearSelection() {
		tokenSelectionGroup?.clear();
	}

	function buildContextForTokenManagement(): Tokens.Context {
		return {
			boardHistory: historyOf($loadedBoardId),
			socket: $socket
		};
	}

	function onPlaceToken(ev: TokenPlacementEvent) {
		Tokens.createNewToken(
			{
				position: ev.position,
				tokenTemplateId: ev.templateId ?? null,
				onServerSideCreation: (instantiatedToken) => {
					tokenSelectionGroup!.select(instantiatedToken, { additive: false });
				}
			},
			buildContextForTokenManagement()
		);
	}

	const onPressDelete = listenTo('Delete');
	$onPressDelete.handle(() => {
		if (selectedTokens.length > 0) {
			Tokens.deleteTokens(selectedTokens, buildContextForTokenManagement());
		}
	});

	const onPressEscape = listenTo('Escape');
	$onPressEscape.handle(() => {
		if ($unplacedTokenProperties) {
			exitTokenPlacement();
		}
	});
</script>

<SelectionGroup
	bind:this={tokenSelectionGroup}
	elements={tokens}
	getElementKey={(token) => token.id}
	bind:selectedElements={selectedTokens}
	bind:selectedKeys={selectedTokenIds}
>
	{#snippet children({ element, isSelected })}
		<Token
			token={element}
			template={getTemplateForToken(element, tokenTemplates)}
			selected={isSelected}
		/>
	{/snippet}
</SelectionGroup>

{#if $unplacedTokenProperties && unplacedTokenSpawnPosition}
	{#key $unplacedTokenProperties.tokenTemplate?.id}
		<UnplacedToken
			template={$unplacedTokenProperties.tokenTemplate}
			spawnPosition={unplacedTokenSpawnPosition}
			onPlace={onPlaceToken}
		/>
	{/key}
{/if}
