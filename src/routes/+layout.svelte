<script>
	import SocketProvider from 'components/extensions/SocketProvider.svelte';
	import UndoRedoListener from 'components/extensions/UndoRedoListener.svelte';
	import { ModalProvider } from 'components/modal';
	import '../styles/style.scss';
	import Header from './Header.svelte';
</script>

<SocketProvider>
	<ModalProvider>
		<UndoRedoListener>
			<Header />

			<slot />
		</UndoRedoListener>
	</ModalProvider>
</SocketProvider>
