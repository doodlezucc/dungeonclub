<script>
	import { Session } from 'client/state';
	import Collection from 'components/Collection.svelte';
	import Icon from 'components/Icon.svelte';
	import Column from 'components/layout/Column.svelte';
	import Container from 'components/layout/Container.svelte';
	import FileUploader from 'components/upload/FileUploader.svelte';
	import TokenTemplateItem from './TokenTemplateItem.svelte';

	const tokenTemplates = Session.instance.campaign.tokenTemplates.withFallback([]);

	function addToken() {
		$tokenTemplates = [
			...$tokenTemplates,
			{
				id: 'no-id',
				avatar: null,
				name: '',
				size: 1
			}
		];
	}
</script>

<Container>
	<Column gap="normal">
		<Collection items={$tokenTemplates} let:item>
			<TokenTemplateItem template={item} />

			<svelte:fragment slot="plus">
				<FileUploader on:change={addToken}>
					Add
					<Icon icon="image" />
				</FileUploader>
			</svelte:fragment>
		</Collection>
	</Column>
</Container>
