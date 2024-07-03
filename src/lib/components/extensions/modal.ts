import type { ModalContext } from '../modal';
import ErrorDialog from './ErrorDialog.svelte';

export async function displayErrorDialog(modal: ModalContext, error: unknown) {
	await modal.display(ErrorDialog, { error });
}
