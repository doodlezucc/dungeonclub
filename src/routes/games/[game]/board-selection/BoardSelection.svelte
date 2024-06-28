<script>
	import Button from '$lib/kit/Button.svelte';
	import Collection from '$lib/kit/Collection.svelte';
	import Column from '$lib/kit/layout/Column.svelte';
	import Container from '$lib/kit/layout/Container.svelte';
	import Text from '$lib/kit/Text.svelte';
	import BoardPreview from './BoardPreview.svelte';

	export let boardSnippets = [
		{
			id: '1',
			name: 'First Board'
		},
		{
			id: 2,
			name: 'Another Board'
		}
	];
</script>

<Container>
	<Column gap="big" align="center">
		<Text style="heading">Boards</Text>

		<Collection items={boardSnippets} let:item={snippet}>
			<BoardPreview name={snippet.name} />

			<svelte:fragment slot="plus">
				<Button raised>New Board</Button>
			</svelte:fragment>
		</Collection>
	</Column>
</Container>
