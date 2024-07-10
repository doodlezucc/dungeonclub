<script lang="ts" context="module">
	export enum ShortcutAction {
		Undo = 'Undo',
		Redo = 'Redo'
	}

	export type ActionListener = [ShortcutAction, () => void];

	export enum ShortcutToggle {
		DisableGridSnapping = 'Disable Grid Snapping'
	}

	interface ListenerHandle {
		handle: (handler: () => void) => void;
	}

	export function listenTo(action: ShortcutAction) {
		let activeListener: ActionListener | undefined = undefined;

		const { subscribe } = readable<ListenerHandle>(
			{
				handle: (handler) => {
					activeListener = [action, handler];
					actionListeners.push(activeListener);
				}
			},
			() => {
				return () => {
					actionListeners = actionListeners.filter((registered) => registered != activeListener);
				};
			}
		);

		return {
			subscribe
		};
	}

	let actionListeners: ActionListener[] = [];

	function handleAction(action: ShortcutAction) {
		for (const [handledAction, listener] of actionListeners) {
			if (handledAction === action) {
				listener();
			}
		}
	}
</script>

<script lang="ts">
	import { ShortcutManager } from '$lib/packages/shortcut-manager';
	import { readable } from 'svelte/store';

	const shortcutManager = new ShortcutManager<ShortcutAction, ShortcutToggle>(handleAction);

	shortcutManager.bind({ ctrl: 'z' }, ShortcutAction.Undo);
	shortcutManager.bind({ ctrl: 'y' }, ShortcutAction.Redo);
	shortcutManager.bind({ ctrlShift: 'z' }, ShortcutAction.Redo);

	shortcutManager.bindToggle(
		{ alt: true, ctrl: false, key: null, shift: false },
		ShortcutToggle.DisableGridSnapping
	);
</script>

<svelte:window
	on:keydown={(ev) => {
		shortcutManager.handleShortcutAction(ev);
		shortcutManager.triggerToggles(ev, true);
	}}
	on:keyup={(ev) => {
		shortcutManager.triggerToggles(ev, false);
	}}
/>

<slot />
