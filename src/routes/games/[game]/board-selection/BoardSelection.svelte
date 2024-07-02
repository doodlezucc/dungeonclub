<script lang="ts">
	import { rest } from '$lib/client/communication';
	import { session } from '$lib/client/state';
	import { Button, Collection, Text } from 'components';
	import { Column, Container } from 'components/layout';
	import BoardPreview from './BoardPreview.svelte';

	$: boardSnippets = $session?.campaign.boards;

	async function createNewBoard() {
		const response = await $rest.post(`/campaigns/${$session!.campaign.id}/boards`, {
			body: 'thisisnowconsidereddata'
		});

		boardSnippets = [...(boardSnippets ?? []), response];
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
