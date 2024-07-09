<script lang="ts">
	import { defineKeyBindings } from 'client/shortcuts';
	import { focusedHistory } from 'client/state/focused-history';
	import type { ModalContext } from 'components/modal';
	import { getContext } from 'svelte';

	const modal = getContext<ModalContext>('modal');

	const undoRedoBindings = defineKeyBindings((bind) => {
		async function undo() {
			const undoResult = await $focusedHistory?.undo();
			if (!undoResult) return;

			const { actionName } = undoResult;
			modal.displayToast({
				text: `Undo: ${actionName}`,
				icon: 'undo-alt'
			});
		}

		async function redo() {
			const redoResult = await $focusedHistory?.redo();
			if (!redoResult) return;

			const { actionName } = redoResult;
			modal.displayToast({
				text: `Redo: ${actionName}`,
				icon: 'redo-alt'
			});
		}

		bind({ ctrl: 'z' }, undo);
		bind({ ctrl: 'y' }, redo);
		bind({ ctrlShift: 'z' }, redo);
	});
</script>

<svelte:window on:keydown={(ev) => undoRedoBindings.handleShortcut(ev)} />

<slot />
