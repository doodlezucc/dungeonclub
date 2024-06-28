<script lang="ts">
	import type { CampaignSnippet } from '$lib/client/account';
	import Button from '$lib/kit/Button.svelte';
	import Dialog from '$lib/kit/Dialog.svelte';
	import Input from '$lib/kit/Input.svelte';
	import type { ModalContext } from '$lib/kit/ModalProvider.svelte';
	import { getContext, onMount } from 'svelte';

	export let campaign: CampaignSnippet;

	$: name = '';

	onMount(() => {
		name = campaign.name;
	});

	const modal = getContext<ModalContext>('modal');

	function save() {
		modal.pop({
			...campaign,
			name
		});
	}
</script>

<Dialog title="Edit Campaign">
	<Input label="Campaign Name" name="Campaign Name" placeholder="Name..." bind:value={name} />

	<svelte:fragment slot="actions">
		<Button type="submit" raised highlight on:click={save}>Save</Button>
	</svelte:fragment>
</Dialog>
