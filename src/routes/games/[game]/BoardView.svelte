<script>
	import { session } from '$lib/client/state';
	import { Align, Stack } from 'components/layout';
	import { onMount } from 'svelte';
	import BoardSelection from './board-selection/BoardSelection.svelte';
	import Board from './board/Board.svelte';
	import BoardTools from './board/BoardTools.svelte';
	import TokenPalette from './board/TokenPalette.svelte';

	$: showBoardSelection = false;

	onMount(() => {
		showBoardSelection = true;
	});
</script>

<Stack expand>
	{#if $session?.visibleBoard}
		<Board />
	{/if}

	<Align alignment="top-left" margin="normal">
		<BoardTools />
	</Align>

	<Align alignment="top-right" margin="normal">
		<TokenPalette />
	</Align>

	{#if showBoardSelection}
		<Align alignment="center">
			<BoardSelection />
		</Align>
	{/if}
</Stack>
