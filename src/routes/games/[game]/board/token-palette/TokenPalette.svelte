<script lang="ts">
	import { rest } from 'client/communication';
	import { Session, sessionState } from 'client/state';
	import Collection from 'components/Collection.svelte';
	import { runWithErrorDialogBoundary } from 'components/extensions/modal';
	import Icon from 'components/Icon.svelte';
	import Column from 'components/layout/Column.svelte';
	import type { ModalContext } from 'components/modal';
	import FileUploader from 'components/upload/FileUploader.svelte';
	import type { TokenTemplateSnippet } from 'shared';
	import { getContext } from 'svelte';
	import Panel from '../Panel.svelte';
	import TokenTemplateItem from './TokenTemplateItem.svelte';

	const tokenTemplates = Session.instance.campaign.tokenTemplates.withFallback([]);

	const modal = getContext<ModalContext>('modal');

	async function createNewTokensFromFiles(ev: CustomEvent<File[]>) {
		const files = ev.detail;

		await runWithErrorDialogBoundary(modal, async () => {
			for (const file of files) {
				const isImage = file.type.startsWith('image/');

				if (isImage) {
					const response: TokenTemplateSnippet = await $rest.post(
						`/campaigns/${$sessionState.campaign!.id}/token-templates`,
						{
							body: {
								contentType: file.type,
								data: await file.arrayBuffer()
							}
						}
					);

					$tokenTemplates = [...$tokenTemplates, response];
				}
			}
		});
	}
</script>

<Panel title="Token Palette">
	<Column gap="normal">
		<div class="token-palette-list">
			<Collection itemClass="token-palette-item" items={$tokenTemplates} let:item>
				<TokenTemplateItem template={item} />
			</Collection>
		</div>

		<FileUploader
			accept="image/*"
			acceptMultiple
			buttonClass="token-palette-item"
			on:change={createNewTokensFromFiles}
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
		overflow-y: auto;
	}
</style>
