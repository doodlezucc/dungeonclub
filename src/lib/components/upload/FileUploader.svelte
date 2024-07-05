<script lang="ts">
	import Icon, { type IconID } from 'components/Icon.svelte';
	import { createEventDispatcher } from 'svelte';

	export let displayedIcon: IconID | undefined = undefined;

	$: dragOver = false;
	$: fileList = null as FileList | null;

	let input: HTMLInputElement;
	function openFilePicker() {
		input.click();
	}

	const dispatch = createEventDispatcher();

	$: {
		if (fileList) {
			dispatch('change', fileList);

			// Clear input element state to allow picking the same file again
			input.value = '';
		}
	}

	function handleDrop(ev: DragEvent) {
		dragOver = false;
		ev.preventDefault();
		const files = ev.dataTransfer?.files;

		if (files) {
			fileList = files;
		}
	}

	function handlePick() {
		if (input.files) {
			fileList = input.files;
		}
	}
</script>

<button
	id="upload-button"
	on:click={openFilePicker}
	on:dragenter={() => (dragOver = true)}
	on:dragover={(ev) => ev.preventDefault()}
	on:dragleave={() => (dragOver = false)}
	on:drop={handleDrop}
	type="button"
	aria-describedby="file-upload"
	class="drop-area"
	class:drag-over={dragOver}
>
	{#if displayedIcon}
		<div class="upload-icon">
			<Icon icon={displayedIcon} />
		</div>
	{/if}

	<slot />
</button>
<input
	bind:this={input}
	on:change={handlePick}
	type="file"
	id="file-upload"
	aria-labelledby="upload-button"
	hidden
/>

<style lang="scss">
	.upload-icon {
		font-size: 3em;
		opacity: 0.5;
		margin-bottom: 0.1em;
	}

	.drop-area {
		border-style: dashed;

		&:hover,
		&:active,
		&:focus-visible,
		&.drag-over {
			border-style: solid;
			outline: 2px dashed var(--color-text);
		}

		&:hover,
		&:focus-visible,
		&.drag-over {
			outline-offset: 6.9px;
		}

		&:active {
			outline-offset: 2.5px;
		}

		> * {
			pointer-events: none;
		}
	}
</style>
