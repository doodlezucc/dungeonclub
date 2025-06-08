<script lang="ts">
	import { rest, socket } from '$lib/client/communication';
	import { Board, Campaign, campaignState } from '$lib/client/state';
	import { displayErrorDialog } from '$lib/ui/util/modal';
	import { ArrangedCollection, Dialog, FileUploader, Row, type ModalContext } from 'packages/ui';
	import { getContext } from 'svelte';
	import { derived } from 'svelte/store';
	import BoardPreview from './BoardPreview.svelte';

	const boardSnippets = derived(campaignState, (campaign) => campaign?.boards);

	const modal = getContext<ModalContext>('modal');

	async function createNewBoardsFromFiles(files: File[]) {
		try {
			for (const file of files) {
				const isImage = file.type.startsWith('image/');

				if (isImage) {
					const { boardId } = await $rest.postFile(`/campaigns/${$campaignState!.id}/boards`, file);

					const createdBoard = await $socket.request('boardEdit', { id: boardId });

					Board.instance.load(createdBoard);
					Campaign.instance.put((campaign) => ({
						...campaign,
						boards: [...campaign.boards, createdBoard]
					}));
				}
			}

			modal.pop();
		} catch (error) {
			displayErrorDialog(modal, error);
		}
	}

	async function selectBoard(boardId: string) {
		await Board.instance.request({
			boardId,
			mode: 'edit'
		});
		modal.pop();
	}
</script>

<Dialog title="Select Board">
	{#if $boardSnippets}
		<Row gap="normal" wrap>
			<ArrangedCollection items={$boardSnippets}>
				{#snippet children({ item: snippet })}
					<BoardPreview name={snippet.name} onclick={() => selectBoard(snippet.id)} />
				{/snippet}
				{#snippet plus()}
					<FileUploader
						accept="image/*"
						acceptMultiple
						displayedIcon="file-image"
						onChange={createNewBoardsFromFiles}
					>
						New Board
					</FileUploader>
				{/snippet}
			</ArrangedCollection>
		</Row>
	{/if}
</Dialog>
