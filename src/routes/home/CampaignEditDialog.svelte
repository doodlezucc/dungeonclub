<script lang="ts">
	import { displayErrorDialog } from '$lib/client/components/modal';
	import { socket } from '$lib/stores';
	import { Button, Input } from 'components';
	import { Dialog, type ModalContext } from 'components/modal';
	import { getContext } from 'svelte';

	export let id: string | undefined = undefined;
	export let name: string;

	const modal = getContext<ModalContext>('modal');

	async function save() {
		try {
			const commonSettings = {
				name,
				playerCharacters: []
			};

			let result;
			if (id) {
				result = await $socket.request('campaignEdit', {
					id: id,
					...commonSettings
				});
			} else {
				result = await $socket.request('campaignCreate', commonSettings);
			}

			modal.pop(result);
		} catch (err) {
			displayErrorDialog(modal, err);
		}
	}
</script>

<Dialog title="Edit Campaign">
	<Input label="Campaign Name" name="Campaign Name" placeholder="Name..." bind:value={name} />

	<svelte:fragment slot="actions">
		<Button type="submit" raised highlight on:click={save}>Save</Button>
	</svelte:fragment>
</Dialog>
