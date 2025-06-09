<script lang="ts">
	import { socket } from '$lib/client/communication';
	import { boardState, Campaign, campaignState } from '$lib/client/state';
	import type { TokenPresetSnippet } from '$lib/net';
	import { runWithErrorDialogBoundary } from '$lib/ui/util/modal';
	import { Collection, Column, FileUploader, Icon, type ModalContext } from 'packages/ui';
	import { historyOf } from 'packages/undo-redo/history';
	import { getContext } from 'svelte';
	import Panel from '../Panel.svelte';
	import { exitTokenPlacement } from '../tokens/UnplacedToken.svelte';
	import { restPostTokenPreset } from './token-palette-management';
	import TokenPresetItem from './TokenPresetItem.svelte';

	const tokenPresets = Campaign.instance.tokenPresets.withFallback([]);

	const modal = getContext<ModalContext>('modal');

	async function createNewPresetsFromFiles(files: File[]) {
		await runWithErrorDialogBoundary(modal, async () => {
			for (const file of files) {
				const isImage = file.type.startsWith('image/');

				if (isImage) {
					await restPostTokenPreset({ avatarImageFile: file });
				}
			}
		});
	}

	async function deleteTokenPreset(deletedPreset: TokenPresetSnippet) {
		exitTokenPlacement();

		// Although it's not really part of the board, deletion of a token
		// preset gets registered on the visible board's undo stack.
		historyOf($boardState?.id ?? $campaignState!.id).registerUndoable('Delete token preset', () => {
			$socket.send('tokenPresetDelete', { tokenPresetId: deletedPreset.id });

			const tokenPresetsBeforeDelete = $tokenPresets;
			$tokenPresets = $tokenPresets.filter((preset) => preset.id !== deletedPreset.id);

			return {
				undo: () => {
					$socket.send('tokenPresetRestore', { tokenPresetId: deletedPreset.id });

					$tokenPresets = tokenPresetsBeforeDelete;
				}
			};
		});
	}
</script>

<Panel title="Token Palette">
	<Column gap="normal">
		<div class="token-palette-list">
			<Collection
				itemClass="token-palette-item"
				items={$tokenPresets}
				keyFunction={(preset) => preset.id}
			>
				{#snippet item(item)}
					<TokenPresetItem preset={item} handleDelete={() => deleteTokenPreset(item)} />
				{/snippet}
			</Collection>
		</div>

		<FileUploader
			accept="image/*"
			acceptMultiple
			buttonClass="token-palette-item"
			onChange={createNewPresetsFromFiles}
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
