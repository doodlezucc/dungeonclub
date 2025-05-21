<script lang="ts" module>
	export type AcceptedFileType = 'audio/*' | 'image/*';
</script>

<script lang="ts">
	import { run } from 'svelte/legacy';

	import Icon, { type IconID } from 'components/Icon.svelte';
	import { createEventDispatcher, type Snippet } from 'svelte';

	interface Props {
		accept: AcceptedFileType;
		acceptMultiple?: boolean;
		buttonClass?: string;
		displayedIcon?: IconID | undefined;
		children?: Snippet;
	}

	let {
		accept,
		acceptMultiple = false,
		buttonClass = 'raised',
		displayedIcon = undefined,
		children
	}: Props = $props();

	let dragOver = $state(false);

	let fileList;
	run(() => {
		fileList = null as File[] | null;
	});

	let input: HTMLInputElement = $state();
	function openFilePicker() {
		input.click();
	}

	const dispatch = createEventDispatcher<{
		change: File[];
	}>();

	run(() => {
		if (fileList) {
			dispatch('change', fileList);

			// Clear input element state to allow picking the same file again
			input.value = '';
		}
	});

	function handleDrop(ev: DragEvent) {
		dragOver = false;
		ev.preventDefault();
		const files = ev.dataTransfer?.files;

		if (files) {
			if (acceptMultiple) {
				fileList = Array.from(files);
			} else {
				fileList = files.length >= 1 ? [files.item(0)!] : [];
			}
		}
	}

	function handlePick() {
		if (input.files) {
			fileList = Array.from(input.files);
		}
	}
</script>

<button
	id="upload-button"
	onclick={openFilePicker}
	ondragenter={() => (dragOver = true)}
	ondragover={(ev) => ev.preventDefault()}
	ondragleave={() => (dragOver = false)}
	ondrop={handleDrop}
	type="button"
	aria-describedby="file-upload"
	class={buttonClass}
	class:drop-area={true}
	class:drag-over={dragOver}
>
	{#if displayedIcon}
		<div class="upload-icon">
			<Icon icon={displayedIcon} />
		</div>
	{/if}

	{@render children?.()}
</button>
<input
	{accept}
	multiple={acceptMultiple}
	bind:this={input}
	onchange={handlePick}
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
	}

	:global(.drop-area > *) {
		pointer-events: none;
	}
</style>
