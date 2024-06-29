<script lang="ts">
	import Button from '$lib/kit/Button.svelte';
	import Collection from '$lib/kit/Collection.svelte';
	import Column from '$lib/kit/layout/Column.svelte';
	import Container from '$lib/kit/layout/Container.svelte';
	import Text from '$lib/kit/Text.svelte';
	import type { BoardPreviewSnippet } from '$lib/net/snippets/board';
	import { socket } from '$lib/stores';
	import BoardPreview from './BoardPreview.svelte';

	export let boardSnippets: BoardPreviewSnippet[] = [];

	async function createNewBoard() {
		const response = await $socket.request('boardCreate', {});
		console.log(response);
	}
</script>

<Container>
	<Column gap="big" align="center">
		<Text style="heading">Boards</Text>

		<Collection items={boardSnippets} let:item={snippet}>
			<BoardPreview name={snippet.name} />

			<svelte:fragment slot="plus">
				<Button raised on:click={createNewBoard}>New Board</Button>
			</svelte:fragment>
		</Collection>
	</Column>
</Container>
