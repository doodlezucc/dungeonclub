<script>
	import Align from '$lib/kit/layout/Align.svelte';
	import Stack from '$lib/kit/layout/Stack.svelte';
	import Board from './board/Board.svelte';
	import BoardTools from './board/BoardTools.svelte';
	import TokenPalette from './board/TokenPalette.svelte';
</script>

<Stack expand>
	<Board />

	<Align alignment="top-left" margin="normal">
		<BoardTools />
	</Align>

	<Align alignment="top-right" margin="normal">
		<TokenPalette />
	</Align>
</Stack>
