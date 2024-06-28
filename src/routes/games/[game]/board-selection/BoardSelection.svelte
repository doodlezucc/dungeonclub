<script>
	import Column from '$lib/kit/layout/Column.svelte';
	import Container from '$lib/kit/layout/Container.svelte';
	import Row from '$lib/kit/layout/Row.svelte';
	import Text from '$lib/kit/Text.svelte';
	import BoardPreview from './BoardPreview.svelte';

	export let boardSnippets = [
		{
			name: 'First Board'
		},
		{
			name: 'Another Board'
		}
	];
</script>

<Container>
	<Column gap="big" align="center">
		<Text style="heading">Boards</Text>

		<Row gap="normal" wrap>
			{#each boardSnippets as boardSnippet}
				<BoardPreview name={boardSnippet.name} />
			{/each}
		</Row>
	</Column>
</Container>
