<script>
	import { session } from '$lib/client/socket';
	import Align from '$lib/kit/layout/Align.svelte';
	import Stack from '$lib/kit/layout/Stack.svelte';
	import BoardSelection from './board-selection/BoardSelection.svelte';
	import Board from './board/Board.svelte';
	import BoardTools from './board/BoardTools.svelte';
	import TokenPalette from './board/TokenPalette.svelte';
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

	<Align alignment="center">
		<BoardSelection />
	</Align>
</Stack>
