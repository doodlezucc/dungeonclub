<script lang="ts">
	import Center from '$lib/kit/layout/Center.svelte';
	import Column from '$lib/kit/layout/Column.svelte';
	import Container from '$lib/kit/layout/Container.svelte';
	import LinkButton from '$lib/kit/LinkButton.svelte';
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
			<LinkButton raised href="games/{id}">Host Session</LinkButton>
		</Center>
	</Column>
</Container>

<style>
	h2 {
		margin: 0;
	}
</style>
