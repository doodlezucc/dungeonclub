<script lang="ts">
	import type { CampaignSnippet } from '$lib/client/account';
	import Button from '$lib/kit/Button.svelte';
	import Dialog from '$lib/kit/Dialog.svelte';
	import Input from '$lib/kit/Input.svelte';
	import type { ModalContext } from '$lib/kit/ModalProvider.svelte';
	import Text from '$lib/kit/Text.svelte';
	import { getContext, onMount } from 'svelte';

	export let campaign: CampaignSnippet;

	$: name = '';

	onMount(() => {
		name = campaign.name;
	});

	const modal = getContext<ModalContext>('modal');
</script>

<Dialog title="Edit Campaign">
	<Text>This is text!</Text>

	<Input label="Campaign Name" name="Campaign Name" placeholder="Name..." bind:value={name} />

	<svelte:fragment slot="actions">
		<Button raised>Cancel</Button>
		<Button type="submit" raised highlight on:click={() => modal.pop(true)}>Save</Button>
	</svelte:fragment>
</Dialog>
