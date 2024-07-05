<script lang="ts">
	import { rest } from 'client/communication';
	import { Board, sessionState } from 'client/state';
	import { Collection } from 'components';
	import { displayErrorDialog } from 'components/extensions/modal';
	import { Dialog, type ModalContext } from 'components/modal';
	import FileUploader from 'components/upload/FileUploader.svelte';
	import { getContext } from 'svelte';
	import BoardPreview from './BoardPreview.svelte';

	$: boardSnippets = $sessionState.campaign?.boards;

	const modal = getContext<ModalContext>('modal');

	async function createNewBoardsFromFiles(ev: CustomEvent<FileList>) {
		const files = ev.detail;

		try {
			for (const file of files) {
				const isImage = file.type.startsWith('image/');

				if (isImage) {
					const response = await $rest.post(`/campaigns/${$sessionState.campaign!.id}/boards`, {
						body: {
							contentType: file.type,
							data: await file.arrayBuffer()
						}
					});

					boardSnippets = [...(boardSnippets ?? []), response];
					Board.instance.load(response);
				}
			}

			modal.pop();
		} catch (error) {
			displayErrorDialog(modal, error);
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
				<FileUploader displayedIcon="file-image" on:change={createNewBoardsFromFiles}>
					New Board
				</FileUploader>
			</svelte:fragment>
		</Collection>
	{/if}
</Dialog>
