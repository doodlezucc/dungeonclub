<script lang="ts">
	import { boardState, sessionState } from 'client/state';
	import { Align, Stack } from 'components/layout';
	import type { ModalContext } from 'components/modal';
	import { getContext } from 'svelte';
	import SelectBoardDialog from './board-selection/SelectBoardDialog.svelte';
	import Board from './board/Board.svelte';
	import BoardTools from './board/BoardTools.svelte';
	import TokenPalette from './board/token-palette/TokenPalette.svelte';

	const modal = getContext<ModalContext>('modal');

	$: selectBoardDialogIsVisible = false;

	async function showBoardSelection() {
		selectBoardDialogIsVisible = true;
		await modal.display(SelectBoardDialog, {});
	}

	$: if (!selectBoardDialogIsVisible) {
		const loadedCampaign = $sessionState.campaign;

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
		<TokenPalette />
	</Align>
</Stack>
