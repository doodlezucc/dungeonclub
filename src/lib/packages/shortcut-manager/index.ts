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

interface ToggleTrigger {
	key: string | null;
	ctrl: boolean;
	shift: boolean;
	alt: boolean;
}

type ActionHandler<T> = (action: T) => void;

export class ShortcutManager<ACTION, TOGGLE> {
	private readonly actionBindings: [LookupShortcut, ACTION][] = [];
	private readonly toggleBindings: [ToggleTrigger, TOGGLE][] = [];

	private readonly activeToggles = new Set<TOGGLE>();

	constructor(private readonly actionHandler: ActionHandler<ACTION>) {}

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

	bind(shortcut: Shortcut, action: ACTION) {
		const lookupShortcut = ShortcutManager.convertShortcutToLookup(shortcut);

		this.actionBindings.push([lookupShortcut, action]);
	}

	bindToggle(trigger: ToggleTrigger, toggle: TOGGLE) {
		this.toggleBindings.push([trigger, toggle]);
	}

	handleShortcutAction(ev: KeyboardEvent): boolean {
		if (!ev.key) return false;

		const keyNormalized = ev.key.toLowerCase();

		for (const [shortcut, action] of this.actionBindings) {
			if (
				shortcut.key === keyNormalized &&
				shortcut.ctrl == ev.ctrlKey &&
				shortcut.shift == ev.shiftKey
			) {
				this.actionHandler(action);
				ev.preventDefault();
				return true;
			}
		}

		return false;
	}

	triggerToggles(ev: KeyboardEvent, isKeyDownEvent: boolean) {
		for (const [trigger, toggle] of this.toggleBindings) {
			const isTriggeringKey = trigger.key == null || trigger.key === ev.key;

			if (
				isTriggeringKey &&
				trigger.ctrl == ev.ctrlKey &&
				trigger.shift == ev.shiftKey &&
				trigger.alt == ev.altKey
			) {
				if (isKeyDownEvent) {
					this.activeToggles.add(toggle);
				} else {
					this.activeToggles.delete(toggle);
				}
			}
		}
	}
}
