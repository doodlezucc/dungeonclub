<script>
	import { ModalProvider } from 'components';
	import '../styles/style.scss';
	import Header from './Header.svelte';
	import SocketProvider from './SocketProvider.svelte';
</script>

<SocketProvider>
	<ModalProvider>
		<Header />

		<slot />
	</ModalProvider>
</SocketProvider>
