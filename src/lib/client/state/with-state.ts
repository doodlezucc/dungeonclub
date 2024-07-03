import { readonly, writable, type Readable, type Writable } from 'svelte/store';

export abstract class WithState<T> {
	private readonly _state: Writable<T | null>;
	readonly state: Readable<T | null>;

	constructor() {
		this._state = writable<T | null>(null);
		this.state = readonly(this._state);
	}

	protected set(state: T) {
		this._state.set(state);
	}
}
