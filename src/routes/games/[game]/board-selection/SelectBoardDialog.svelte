<script lang="ts">
	import { rest } from '$lib/client/communication';
	import ErrorDialog from '$lib/client/components/ErrorDialog.svelte';
	import { Board, sessionState } from '$lib/client/state';
	import { Button, Collection } from 'components';
	import { Dialog, type ModalContext } from 'components/modal';
	import { getContext } from 'svelte';
	import BoardPreview from './BoardPreview.svelte';

	$: boardSnippets = $sessionState.campaign?.boards;

	const modal = getContext<ModalContext>('modal');

	async function createNewBoard() {
		try {
			const response = await $rest.post(`/campaigns/${$sessionState.campaign!.id}/boards`, {
				body: 'thisisnowconsidereddata'
			});

			boardSnippets = [...(boardSnippets ?? []), response];
			Board.instance.load(response);
			modal.pop();
		} catch (error) {
			modal.display(ErrorDialog, { error });
		}
	}

	async function selectBoard(boardId: string) {
		await Board.instance.view(boardId);
		modal.pop();
	}
</script>

<Dialog title="Select Board">
	{#if boardSnippets}
		<Collection items={boardSnippets} let:item={snippet}>
			<BoardPreview name={snippet.name} on:click={() => selectBoard(snippet.id)} />

			<svelte:fragment slot="plus">
				<Button raised on:click={createNewBoard}>New Board</Button>
			</svelte:fragment>
		</Collection>
	{/if}
</Dialog>
