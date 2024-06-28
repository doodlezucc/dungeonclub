<script lang="ts">
	import Button from '$lib/kit/Button.svelte';
	import Dialog from '$lib/kit/Dialog.svelte';
	import Input from '$lib/kit/Input.svelte';
	import type { ModalContext } from '$lib/kit/ModalProvider.svelte';
	import { socket } from '$lib/stores';
	import { getContext } from 'svelte';

	export let id: string | undefined = undefined;
	export let name: string;

	const modal = getContext<ModalContext>('modal');

	async function save() {
		try {
			const commonSettings = {
				name
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
			modal.displayError(err);
		}
	}
</script>

<Dialog title="Edit Campaign">
	<Input label="Campaign Name" name="Campaign Name" placeholder="Name..." bind:value={name} />

	<svelte:fragment slot="actions">
		<Button type="submit" raised highlight on:click={save}>Save</Button>
	</svelte:fragment>
</Dialog>
