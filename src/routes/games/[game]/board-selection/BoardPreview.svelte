<script lang="ts">
	import Button from '$lib/kit/Button.svelte';
	import Column from '$lib/kit/layout/Column.svelte';
	import Container from '$lib/kit/layout/Container.svelte';
	import Text from '$lib/kit/Text.svelte';

	export let name: string;
</script>

<Container>
	<Column align="center">
		<Text>{name}</Text>
		<Button highlight>Edit</Button>
	</Column>
</Container>
