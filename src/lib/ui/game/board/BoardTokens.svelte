<script lang="ts">
	import { socket } from '$lib/client/communication';
	import { boardState, campaignState } from '$lib/client/state';
	import type { TokenSnippet } from '$lib/net';
	import { EMPTY_TOKEN_PROPERTIES } from '$lib/net/token-materializing';
	import { listenTo } from '$lib/ui/util/ShortcutListener.svelte';
	import { SelectionGroup } from 'packages/ui';
	import { historyOf } from 'packages/undo-redo/history';
	import { getContext } from 'svelte';
	import { derived as storeDerived } from 'svelte/store';
	import { type BoardContext } from './Board.svelte';
	import Token from './tokens/Token.svelte';
	import UnplacedToken, {
		exitTokenPlacement,
		unplacedTokenProperties,
		type TokenPlacementEvent
	} from './tokens/UnplacedToken.svelte';
	import * as Tokens from './tokens/token-management';

	interface Props {
		selectedTokenIds?: string[];
	}

	let { selectedTokenIds = $bindable([]) }: Props = $props();

	const loadedBoardId = storeDerived(boardState, (board) => board!.id);

	let allPresets = $derived($campaignState!.presets);
	let tokens = $derived($boardState!.tokens);

	let tokenSelectionGroup = $state(null as SelectionGroup<TokenSnippet> | null);
	let selectedTokens = $state<TokenSnippet[]>([]);

	$effect(() => {
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
		const properties = ev.presetId
			? allPresets.find((preset) => preset.id === ev.presetId)!
			: EMPTY_TOKEN_PROPERTIES;

		Tokens.createNewToken(
			{
				position: ev.position,
				properties: properties,
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
		<Token token={element} selected={isSelected} />
	{/snippet}
</SelectionGroup>

{#if $unplacedTokenProperties && unplacedTokenSpawnPosition}
	{#key $unplacedTokenProperties.tokenPreset?.id}
		<UnplacedToken
			preset={$unplacedTokenProperties.tokenPreset}
			spawnPosition={unplacedTokenSpawnPosition}
			onPlace={onPlaceToken}
		/>
	{/key}
{/if}
