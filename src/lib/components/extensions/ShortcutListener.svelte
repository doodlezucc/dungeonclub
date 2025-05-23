<script lang="ts" module>
	export type ShortcutAction =
		| 'Escape'
		| 'Undo'
		| 'Redo'
		| 'Copy'
		| 'Cut'
		| 'Paste'
		| 'Delete'
		| 'SelectAll';

	export type ActionListener = [ShortcutAction, () => void];

	export type KeyState = 'DisableGridSnapping' | 'ModifySelectionRange' | 'ModifySelection';

	interface ListenerHandle {
		handle: (handler: () => void) => void;
	}

	export function listenTo(action: ShortcutAction) {
		let activeListener: ActionListener | undefined = undefined;

		return readable<ListenerHandle>(
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
	}

	export function keyStateOf(keyState: KeyState): Readable<boolean> {
		return derived(activeKeyStates, (active) => active.includes(keyState));
	}

	export function derivedKeyStateModifySelection() {
		return derived(
			[keyStateOf('ModifySelection'), keyStateOf('ModifySelectionRange')],
			([doModify, doModifyRange]) => {
				return doModify || doModifyRange;
			}
		);
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
	import type { Snippet } from 'svelte';
	import { run } from 'svelte/legacy';
	import { derived, readable, writable, type Readable } from 'svelte/store';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();

	const shortcutManager = new ShortcutManager<ShortcutAction, KeyState>(handleAction);
	const activeManagerKeyStates = shortcutManager.activeKeyStates;

	run(() => {
		activeKeyStates.set($activeManagerKeyStates);
	});

	shortcutManager.bind('Escape', 'Escape');

	// See https://developer.mozilla.org/en-US/docs/Web/API/UI_Events/Keyboard_event_key_values#editing_keys for reference
	shortcutManager.bind('Undo', 'Undo');
	shortcutManager.bind({ ctrl: 'z' }, 'Undo');

	shortcutManager.bind('Redo', 'Redo');
	shortcutManager.bind({ ctrl: 'y' }, 'Redo');
	shortcutManager.bind({ ctrlShift: 'z' }, 'Redo');

	shortcutManager.bind('Copy', 'Copy');
	shortcutManager.bind({ ctrl: 'c' }, 'Copy');

	shortcutManager.bind('Cut', 'Cut');
	shortcutManager.bind({ ctrl: 'x' }, 'Cut');

	shortcutManager.bind('Paste', 'Paste');
	shortcutManager.bind({ ctrl: 'v' }, 'Paste');

	shortcutManager.bind('Backspace', 'Delete');
	shortcutManager.bind('Delete', 'Delete');

	shortcutManager.bindState({ alt: true }, 'DisableGridSnapping');
	shortcutManager.bindState({ shift: true }, 'ModifySelectionRange');
	shortcutManager.bindState({ ctrl: true }, 'ModifySelection');

	function isNativelyHandled(ev: KeyboardEvent) {
		const focusedElement = ev.target;

		return (
			focusedElement instanceof HTMLInputElement || focusedElement instanceof HTMLTextAreaElement
		);
	}
</script>

<svelte:window
	onkeydown={(ev) => {
		if (!isNativelyHandled(ev)) {
			shortcutManager.handleShortcutAction(ev);
			shortcutManager.updateKeyStates(ev, true);
		}
	}}
	onkeyup={(ev) => {
		shortcutManager.updateKeyStates(ev, false);
	}}
/>

{@render children()}
