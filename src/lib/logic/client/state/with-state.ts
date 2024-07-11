import { readonly, writable, type Readable, type Writable } from 'svelte/store';

export abstract class WithState<T> {
	private _currentState: T | null = null;
	private readonly _state: Writable<T | null>;
	readonly state: Readable<T | null>;

	constructor() {
		this._state = writable<T | null>(null);
		this.state = readonly(this._state);
	}

	protected set(state: T) {
		this._state.set(state);
		this._currentState = state;
	}

	protected put(update: (state: T) => T) {
		if (!this._currentState) {
			throw 'State not set, unable to modify with put()';
		}

		this.set({
			...this._currentState,
			...update(this._currentState)
		});
	}
}
