<script>
	import SocketProvider from 'components/extensions/SocketProvider.svelte';
	import { ModalProvider } from 'components/modal';
	import '../styles/style.scss';
	import Header from './Header.svelte';
</script>

<SocketProvider>
	<ModalProvider>
		<Header />

		<slot />
	</ModalProvider>
</SocketProvider>
