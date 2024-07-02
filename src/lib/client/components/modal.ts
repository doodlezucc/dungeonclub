import type { ModalContext } from 'components/modal';
import ErrorDialog from './ErrorDialog.svelte';

export async function displayErrorDialog(modal: ModalContext, error: unknown) {
	await modal.display(ErrorDialog, { error });
}
