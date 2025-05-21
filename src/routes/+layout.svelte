<script lang="ts">
	import ShortcutListener from 'components/extensions/ShortcutListener.svelte';
	import SocketProvider from 'components/extensions/SocketProvider.svelte';
	import UndoRedoListener from 'components/extensions/UndoRedoListener.svelte';
	import { ModalProvider } from 'components/modal';
	import type { Snippet } from 'svelte';
	import '../styles/style.scss';
	import Header from './Header.svelte';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();
</script>

<SocketProvider>
	<ModalProvider>
		<ShortcutListener>
			<UndoRedoListener>
				<Header />

				{@render children()}
			</UndoRedoListener>
		</ShortcutListener>
	</ModalProvider>
</SocketProvider>
