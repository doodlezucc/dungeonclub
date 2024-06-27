<script>
	import '../styles/style.scss';
	import Header from './Header.svelte';
	import SocketProvider from './SocketProvider.svelte';
</script>

<SocketProvider>
	<Header />

	<slot />
</SocketProvider>
