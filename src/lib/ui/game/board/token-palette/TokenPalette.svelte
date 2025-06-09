<script lang="ts">
	import { socket } from '$lib/client/communication';
	import { boardState, Campaign, campaignState } from '$lib/client/state';
	import type { TokenTemplateSnippet } from '$lib/net';
	import { runWithErrorDialogBoundary } from '$lib/ui/util/modal';
	import { Collection, Column, FileUploader, Icon, type ModalContext } from 'packages/ui';
	import { historyOf } from 'packages/undo-redo/history';
	import { getContext } from 'svelte';
	import Panel from '../Panel.svelte';
	import { exitTokenPlacement } from '../tokens/UnplacedToken.svelte';
	import { restPostTokenTemplate } from './token-palette-management';
	import TokenTemplateItem from './TokenTemplateItem.svelte';

	const tokenTemplates = Campaign.instance.tokenTemplates.withFallback([]);

	const modal = getContext<ModalContext>('modal');

	async function createNewTemplatesFromFiles(files: File[]) {
		await runWithErrorDialogBoundary(modal, async () => {
			for (const file of files) {
				const isImage = file.type.startsWith('image/');

				if (isImage) {
					await restPostTokenTemplate({ avatarImageFile: file });
				}
			}
		});
	}

	async function deleteTokenTemplate(deletedTemplate: TokenTemplateSnippet) {
		exitTokenPlacement();

		// Although it's not really part of the board, deletion of a token
		// template gets registered on the visible board's undo stack.
		historyOf($boardState?.id ?? $campaignState!.id).registerUndoable(
			'Delete token template',
			() => {
				$socket.send('tokenTemplateDelete', { tokenTemplateId: deletedTemplate.id });

				const tokenTemplatesBeforeDelete = $tokenTemplates;
				$tokenTemplates = $tokenTemplates.filter((template) => template.id !== deletedTemplate.id);

				return {
					undo: () => {
						$socket.send('tokenTemplateRestore', { tokenTemplateId: deletedTemplate.id });

						$tokenTemplates = tokenTemplatesBeforeDelete;
					}
				};
			}
		);
	}
</script>

<Panel title="Token Palette">
	<Column gap="normal">
		<div class="token-palette-list">
			<Collection
				itemClass="token-palette-item"
				items={$tokenTemplates}
				keyFunction={(template) => template.id}
			>
				{#snippet item(item)}
					<TokenTemplateItem template={item} handleDelete={() => deleteTokenTemplate(item)} />
				{/snippet}
			</Collection>
		</div>

		<FileUploader
			accept="image/*"
			acceptMultiple
			buttonClass="token-palette-item"
			onChange={createNewTemplatesFromFiles}
		>
			<Icon icon="add" />
		</FileUploader>
	</Column>
</Panel>

<style>
	.token-palette-list {
		display: flex;
		flex-direction: column;
		gap: 1px;
		min-width: 200px;
		max-height: 25vh;
		overflow-x: hidden;
		overflow-y: auto;
	}
</style>
