<script lang="ts">
	import { createEventDispatcher } from 'svelte';

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
	<span>Drag & drop</span>
	<br />
	<span>or click to pick a file</span>
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
	.drop-area {
		background-color: var(--color-background);
		border-radius: 0;
		border: 2px dashed var(--color-separator);
		min-width: 5em;
		min-height: 5em;
		cursor: pointer;
		padding: 2em 3em;
		margin: 1em;
		box-sizing: content-box;
		transition: 0.5s cubic-bezier(0.19, 1, 0.22, 1);

		&:hover,
		&:active,
		&:focus-visible,
		&.drag-over {
			border-color: var(--color-text);
			border-style: solid;
			outline: 2px dashed var(--color-text);
		}

		&:hover,
		&:focus-visible,
		&.drag-over {
			outline-offset: 0.5em;
			padding: 2.5em 3.5em;
			margin: 0.5em;
		}

		&:active {
			transition-duration: 0.2s;
			background-color: var(--color-button);
			outline-offset: 0.3em;
			padding: 2em 3em;
			margin: 1em;
		}

		> * {
			pointer-events: none;
		}
	}
</style>
