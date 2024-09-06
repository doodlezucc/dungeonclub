<script lang="ts">
	import { boardState, campaignState } from 'client/state';
	import { Align, Column, Stack } from 'components/layout';
	import type { ModalContext } from 'components/modal';
	import { getContext } from 'svelte';
	import SelectBoardDialog from './board-selection/SelectBoardDialog.svelte';
	import Board from './board/Board.svelte';
	import BoardTools from './board/BoardTools.svelte';
	import TokenPalette from './board/token-palette/TokenPalette.svelte';
	import TokenPropertiesPanel from './board/token-properties/TokenPropertiesPanel.svelte';

	const modal = getContext<ModalContext>('modal');

	$: selectBoardDialogIsVisible = false;

	async function showBoardSelection() {
		selectBoardDialogIsVisible = true;
		await modal.display(SelectBoardDialog, {});
	}

	$: if (!selectBoardDialogIsVisible) {
		const loadedCampaign = $campaignState;

		// Show board selection if there is no board loaded
		if (loadedCampaign && !$boardState) {
			showBoardSelection();
		}
	}
</script>

<Stack expand>
	{#if $boardState}
		<Board />
	{/if}

	<Align alignment="top-left" margin="normal">
		<BoardTools />
	</Align>

	<Align alignment="top-right" margin="normal">
		<Column gap="big">
			<TokenPalette />
			<TokenPropertiesPanel />
		</Column>
	</Align>
</Stack>
