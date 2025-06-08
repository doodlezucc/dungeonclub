<script lang="ts">
	import 'packages/ui/scss/global.scss';

	import ShortcutListener from 'packages/ui/extensions/ShortcutListener.svelte';
	import SocketProvider from 'packages/ui/extensions/SocketProvider.svelte';
	import UndoRedoListener from 'packages/ui/extensions/UndoRedoListener.svelte';
	import { ModalProvider } from 'packages/ui/modal';
	import type { Snippet } from 'svelte';
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
