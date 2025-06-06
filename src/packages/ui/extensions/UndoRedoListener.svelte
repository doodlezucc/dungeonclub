<script lang="ts">
	import { focusedHistory } from 'client/state/focused-history';
	import type { ModalContext } from 'packages/ui/modal';
	import { getContext, type Snippet } from 'svelte';
	import { listenTo } from './ShortcutListener.svelte';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();

	const modal = getContext<ModalContext>('modal');

	const onUndo = listenTo('Undo');
	$onUndo.handle(async () => {
		const undoResult = await $focusedHistory?.undo();
		if (!undoResult) return;

		const { actionName } = undoResult;
		modal.displayToast({
			text: `Undo: ${actionName}`,
			icon: 'undo-alt'
		});
	});

	const onRedo = listenTo('Redo');
	$onRedo.handle(async () => {
		const redoResult = await $focusedHistory?.redo();
		if (!redoResult) return;

		const { actionName } = redoResult;
		modal.displayToast({
			text: `Redo: ${actionName}`,
			icon: 'redo-alt'
		});
	});
</script>

{@render children()}
