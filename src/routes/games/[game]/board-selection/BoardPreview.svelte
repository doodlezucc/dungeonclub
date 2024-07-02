<script lang="ts">
	import { Button, Text } from 'components';
	import { Column, Container } from 'components/layout';

	export let name: string;
</script>

<Container>
	<Column align="center">
		<Text>{name}</Text>
		<Button highlight>Edit</Button>
	</Column>
</Container>
