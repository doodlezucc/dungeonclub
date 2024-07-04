<script lang="ts">
	import Button from 'components/Button.svelte';
	import Column from 'components/layout/Column.svelte';
	import Dialog from './Dialog.svelte';
	import DropArea from './upload/DropArea.svelte';

	export let title: string = 'Upload';

	async function handleFileDrop(ev: CustomEvent<FileList>) {
		const files = ev.detail;

		for (const file of files) {
			console.log(file.name, file.size, file.type);
		}
	}
</script>

<Dialog {title}>
	<Column gap="big">
		<DropArea on:change={handleFileDrop}></DropArea>
	</Column>

	<svelte:fragment slot="actions">
		<Button raised>OK</Button>
	</svelte:fragment>
</Dialog>
