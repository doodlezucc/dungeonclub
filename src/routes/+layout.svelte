<script>
	import ShortcutListener from 'components/extensions/ShortcutListener.svelte';
	import SocketProvider from 'components/extensions/SocketProvider.svelte';
	import UndoRedoListener from 'components/extensions/UndoRedoListener.svelte';
	import { ModalProvider } from 'components/modal';
	import '../styles/style.scss';
	import Header from './Header.svelte';
	/** @type {{children?: import('svelte').Snippet}} */
	let { children } = $props();
</script>

<SocketProvider>
	<ModalProvider>
		<ShortcutListener>
			<UndoRedoListener>
				<Header />

				{@render children?.()}
			</UndoRedoListener>
		</ShortcutListener>
	</ModalProvider>
</SocketProvider>
