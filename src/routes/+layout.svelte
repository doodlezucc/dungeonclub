<script>
	import ModalProvider from '$lib/kit/ModalProvider.svelte';
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
