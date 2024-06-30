<script lang="ts">
	import { rest, session } from '$lib/client/socket';
	import Button from '$lib/kit/Button.svelte';
	import Collection from '$lib/kit/Collection.svelte';
	import Column from '$lib/kit/layout/Column.svelte';
	import Container from '$lib/kit/layout/Container.svelte';
	import Text from '$lib/kit/Text.svelte';
	import BoardPreview from './BoardPreview.svelte';

	$: boardSnippets = $session?.campaign.boards;

	async function createNewBoard() {
		const response = await $rest.post('/campaigns/ddPlp/boards', {
			body: 'thisisnowconsidereddata'
		});
		console.log(response);
	}
</script>

<Container>
	<Column gap="big" align="center">
		<Text style="heading">Boards</Text>

		{#if boardSnippets}
			<Collection items={boardSnippets} let:item={snippet}>
				<BoardPreview name={snippet.name} />

				<svelte:fragment slot="plus">
					<Button raised on:click={createNewBoard}>New Board</Button>
				</svelte:fragment>
			</Collection>
		{/if}
	</Column>
</Container>
