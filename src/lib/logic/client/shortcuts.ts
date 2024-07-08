type Action = () => void;

type KeyCode = string;

export type Shortcut =
	| KeyCode
	| {
			ctrl: KeyCode;
			shift?: never;
			ctrlShift?: never;
	  }
	| {
			ctrl?: never;
			shift: KeyCode;
			ctrlShift?: never;
	  }
	| {
			ctrl?: never;
			shift?: never;
			ctrlShift: KeyCode;
	  };

type LookupShortcut = {
	key: string;
	ctrl: boolean;
	shift: boolean;
};

type BindFn = (shortcut: Shortcut, action: Action) => void;

class KeyBindings {
	private readonly bindings: [LookupShortcut, Action][] = [];

	private static convertShortcutToLookup(shortcut: Shortcut): LookupShortcut {
		if (typeof shortcut === 'string') {
			return { key: shortcut.toLowerCase(), ctrl: false, shift: false };
		} else {
			const { ctrl, shift, ctrlShift } = shortcut;

			if (ctrl) {
				return { key: ctrl.toLowerCase(), ctrl: true, shift: false };
			} else if (shift) {
				return { key: shift.toLowerCase(), ctrl: false, shift: true };
			} else {
				return { key: ctrlShift!.toLowerCase(), ctrl: true, shift: true };
			}
		}
	}

	bind(shortcut: Shortcut, action: Action) {
		const lookupShortcut = KeyBindings.convertShortcutToLookup(shortcut);

		this.bindings.push([lookupShortcut, action]);
	}

	handleShortcut(ev: KeyboardEvent): boolean {
		if (!ev.key) return false;

		const keyNormalized = ev.key.toLowerCase();

		for (const [shortcut, command] of this.bindings) {
			if (
				shortcut.key === keyNormalized &&
				shortcut.ctrl == ev.ctrlKey &&
				shortcut.shift == ev.shiftKey
			) {
				command();
				ev.preventDefault();
				return true;
			}
		}

		return false;
	}
}

export function defineKeyBindings<T>(build: (bind: BindFn) => T): KeyBindings {
	const result = new KeyBindings();
	build((shortcut, action) => result.bind(shortcut, action));

	return result;
}
