import type { ModalContext } from 'packages/ui/modal';
import ErrorDialog from './ErrorDialog.svelte';

export async function displayErrorDialog(modal: ModalContext, error: unknown) {
	await modal.display(ErrorDialog, { error });
}

export async function runWithErrorDialogBoundary(modal: ModalContext, body: () => Promise<void>) {
	try {
		await body();
	} catch (err) {
		displayErrorDialog(modal, err);
	}
}
