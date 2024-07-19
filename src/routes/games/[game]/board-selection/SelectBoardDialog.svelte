<script lang="ts">
	import { rest } from 'client/communication';
	import { Board, Session, sessionState } from 'client/state';
	import ArrangedCollection from 'components/ArrangedCollection.svelte';
	import { displayErrorDialog } from 'components/extensions/modal';
	import Row from 'components/layout/Row.svelte';
	import { Dialog, type ModalContext } from 'components/modal';
	import FileUploader from 'components/upload/FileUploader.svelte';
	import type { BoardSnippet } from 'shared';
	import { getContext } from 'svelte';
	import { derived } from 'svelte/store';
	import BoardPreview from './BoardPreview.svelte';

	const boardSnippets = derived(sessionState, ({ campaign }) => campaign?.boards);

	const modal = getContext<ModalContext>('modal');

	async function createNewBoardsFromFiles(ev: CustomEvent<FileList>) {
		const files = ev.detail;

		try {
			for (const file of files) {
				const isImage = file.type.startsWith('image/');

				if (isImage) {
					const response: BoardSnippet = await $rest.post(
						`/campaigns/${$sessionState.campaign!.id}/boards`,
						{
							body: {
								contentType: file.type,
								data: await file.arrayBuffer()
							}
						}
					);

					Board.instance.load(response);
					Session.instance.campaign.put((campaign) => ({
						...campaign,
						boards: [...campaign.boards, response]
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
			<ArrangedCollection items={$boardSnippets} let:item={snippet}>
				<BoardPreview name={snippet.name} on:click={() => selectBoard(snippet.id)} />

				<svelte:fragment slot="plus">
					<FileUploader displayedIcon="file-image" on:change={createNewBoardsFromFiles}>
						New Board
					</FileUploader>
				</svelte:fragment>
			</ArrangedCollection>
		</Row>
	{/if}
</Dialog>
