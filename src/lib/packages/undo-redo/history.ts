import { writable } from 'svelte/store';
import type { BidirectionalAction, PromiseOr, UndoableFn } from './action';

export interface HistoryState {
	timeline: BidirectionalAction[];

	/**
	 * Every action up to (including) this index is completed (can only be undone).
	 *
	 * Actions with an `index > presentIndex` are set in the future (can only be redone).
	 */
	presentIndex: number;
}

export const createHistory = () => {
	const { subscribe, update } = writable<HistoryState>({
		timeline: [],
		presentIndex: 0
	});

	let activePromise: Promise<unknown> | null = null;

	async function enqueuePromise<T>(promise: () => PromiseOr<T>): Promise<T> {
		const endOfQueue = (result: T) => {
			activePromise = null;
			return result;
		};

		if (activePromise) {
			const onAllCompleted = activePromise.then(promise).then(endOfQueue);
			activePromise = onAllCompleted;
			return await onAllCompleted;
		} else {
			const promiseResult = promise();
			if (promiseResult instanceof Promise) {
				const onAllCompleted = promiseResult.then(endOfQueue);
				activePromise = onAllCompleted;
				return await onAllCompleted;
			} else {
				return promiseResult;
			}
		}
	}

	function silentRegister(action: BidirectionalAction) {
		update(({ timeline, presentIndex }) => {
			const withoutFutureActions = timeline.slice(0, presentIndex);

			return {
				timeline: [...withoutFutureActions, action],
				presentIndex: presentIndex + 1
			};
		});
	}

	async function register(action: BidirectionalAction) {
		silentRegister(action);
		await enqueuePromise(action.do);
	}

	async function registerUndoable(name: string, doAction: UndoableFn) {
		const { undo } = await enqueuePromise(doAction);

		silentRegister({
			name,
			do: async () => {
				await doAction();
			},
			undo: undo
		});
	}

	async function undo(): Promise<void> {
		return new Promise((resolve) =>
			update(({ timeline, presentIndex }) => {
				if (presentIndex <= 0) {
					resolve();
					return { timeline, presentIndex };
				}

				const actionToUndo = timeline[presentIndex - 1];
				enqueuePromise(() => actionToUndo.undo()).then(() => resolve());

				return {
					presentIndex: presentIndex - 1,
					timeline
				};
			})
		);
	}

	async function redo(): Promise<void> {
		return new Promise((resolve) =>
			update(({ timeline, presentIndex }) => {
				if (presentIndex >= timeline.length) {
					resolve();
					return { timeline, presentIndex };
				}

				const actionToRedo = timeline[presentIndex];
				enqueuePromise(() => actionToRedo.do()).then(() => resolve());

				return {
					presentIndex: presentIndex + 1,
					timeline
				};
			})
		);
	}

	return {
		subscribe,
		register,
		registerUndoable,
		undo,
		redo
	};
};
