<script lang="ts">
	import Button from '$lib/kit/Button.svelte';
	import Center from '$lib/kit/layout/Center.svelte';
	import Column from '$lib/kit/layout/Column.svelte';
	import Container from '$lib/kit/layout/Container.svelte';
	import Text from '$lib/kit/Text.svelte';
	import Time from 'svelte-time/Time.svelte';

	export let id: string;
	export let name: string;
	export let createdAt: Date;
</script>

<Container>
	<h2>{name}</h2>
	<Column gap="big">
		<Text style="subtitle">Created <Time timestamp={createdAt} /></Text>

		<Center>
			<Button highlight raised href="games/{id}">Host Session</Button>
		</Center>
	</Column>
</Container>

<style>
	h2 {
		margin: 0;
	}
</style>
