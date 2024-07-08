<script lang="ts">
	import { defineKeyBindings } from 'client/shortcuts';
	import { focusedHistory } from 'client/state/focused-history';
	import type { ModalContext } from 'components/modal';
	import { getContext } from 'svelte';
	import { get } from 'svelte/store';

	const modal = getContext<ModalContext>('modal');

	const undoRedoBindings = defineKeyBindings((bind) => {
		function undo() {
			get(focusedHistory)?.undo();
			modal.displayToast({
				text: 'Undo',
				icon: 'undo-alt'
			});
		}

		function redo() {
			get(focusedHistory)?.redo();
			modal.displayToast({
				text: 'Redo',
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
