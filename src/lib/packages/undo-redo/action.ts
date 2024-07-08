export type PromiseOr<T> = Promise<T> | T;

export type OneWayAction = () => PromiseOr<void>;

export interface BidirectionalAction {
	name: string;
	do: OneWayAction;
	undo: OneWayAction;
}

type UndoableFnResult = {
	undo: OneWayAction;
};

export type UndoableFn = () => PromiseOr<UndoableFnResult>;
