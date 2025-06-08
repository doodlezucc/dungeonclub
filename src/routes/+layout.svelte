<script lang="ts">
	import '@fontsource-variable/recursive';
	import '@fontsource/fira-mono';
	import '@fontsource/lato';
	import 'packages/ui/scss/global.scss';

	import ShortcutListener from '$lib/ui/util/ShortcutListener.svelte';
	import SocketProvider from '$lib/ui/util/SocketProvider.svelte';
	import UndoRedoListener from '$lib/ui/util/UndoRedoListener.svelte';
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
