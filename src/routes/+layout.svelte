<script>
	import SocketProvider from '$lib/client/components/SocketProvider.svelte';
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
