<script lang="ts" context="module">
</script>

<script lang="ts">
	import type { CampaignSnippet } from '$lib/client/account';

	import Button from '$lib/kit/Button.svelte';
	import IconButton from '$lib/kit/IconButton.svelte';
	import Center from '$lib/kit/layout/Center.svelte';
	import Column from '$lib/kit/layout/Column.svelte';
	import Container from '$lib/kit/layout/Container.svelte';
	import Row from '$lib/kit/layout/Row.svelte';
	import Text from '$lib/kit/Text.svelte';
	import Time from 'svelte-time/Time.svelte';

	export let snippet: CampaignSnippet;

	$: id = snippet.id;
	$: name = snippet.name;
	$: createdAt = snippet.createdAt;

	function editCampaign() {
		alert('edit');
	}
</script>

<Container>
	<Row gap="big" align="center" justify="space-between">
		<h2>{name}</h2>
		<IconButton label="Edit Campaign" on:click={editCampaign} icon="cog" />
	</Row>
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
