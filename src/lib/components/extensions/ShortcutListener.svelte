<script lang="ts" context="module">
	export enum ShortcutAction {
		Undo = 'Undo',
		Redo = 'Redo'
	}

	export type ActionListener = [ShortcutAction, () => void];

	export enum KeyState {
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

	export function keyStateOf(keyState: KeyState): Readable<boolean> {
		return derived(activeKeyStates, (active) => active.includes(keyState));
	}

	let activeKeyStates = writable<KeyState[]>([]);
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
	import { derived, readable, writable, type Readable } from 'svelte/store';

	const shortcutManager = new ShortcutManager<ShortcutAction, KeyState>(handleAction);
	const activeManagerKeyStates = shortcutManager.activeKeyStates;

	$: {
		activeKeyStates.set($activeManagerKeyStates);
	}

	shortcutManager.bind({ ctrl: 'z' }, ShortcutAction.Undo);
	shortcutManager.bind({ ctrl: 'y' }, ShortcutAction.Redo);
	shortcutManager.bind({ ctrlShift: 'z' }, ShortcutAction.Redo);

	shortcutManager.bindState({ alt: true }, KeyState.DisableGridSnapping);
</script>

<svelte:window
	on:keydown={(ev) => {
		shortcutManager.handleShortcutAction(ev);
		shortcutManager.updateKeyStates(ev, true);
	}}
	on:keyup={(ev) => {
		shortcutManager.updateKeyStates(ev, false);
	}}
/>

<slot />
