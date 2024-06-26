import type { AllMessages, MessageName, RequestMessage } from './messages';
import type { TokensMessageCategory } from './tokens';

export type AsPayload<T> = T extends RequestMessage<infer A, unknown> ? A : T;
export type PayloadOf<C, T extends keyof C> = AsPayload<C[T]>;
export type Payload<T extends MessageName> = AsPayload<AllMessages[T]>;

export type AsResponse<T> = T extends RequestMessage<unknown, infer R> ? R : void;
export type ResponseOf<C, T extends keyof C> = AsResponse<C[T]>;
export type Response<T extends MessageName> = AsResponse<AllMessages[T]>;

export type PickStringKeysOf<T> = Pick<T, keyof T & string>;
export type StringKeysOf<T> = keyof PickStringKeysOf<T>;

export type HandlerName<K extends string> = `handle${Capitalize<K>}`;

export type CategoryHandlers<C, O> = {
	[K in StringKeysOf<C> as HandlerName<K>]: (
		payload: PayloadOf<C, K>,
		options: O
	) => Promise<ResponseOf<C, K>>;
};

export abstract class MessageHandler<O> {
	abstract tokens: CategoryHandlers<TokensMessageCategory, O>;

	private _allHandlers: CategoryHandlers<unknown, O>[] | undefined;
	get allHandlers() {
		return (this._allHandlers ??= [this.tokens]);
	}

	handle<T extends MessageName>(name: T, payload: Payload<T>, options: O): Promise<Response<T>> {
		const nameCapitalized = name.substring(0, 1).toUpperCase() + name.substring(1);
		const handlerName = `handle${nameCapitalized}`;

		return this.runHandler(handlerName as HandlerName<T>, payload, options);
	}

	runHandler<T extends MessageName>(
		handlerName: HandlerName<T>,
		payload: Payload<T>,
		options: O
	): Promise<Response<T>> {
		if (handlerName in this.tokens) {
			const handle = this.tokens[handlerName];
			return handle(payload as never, options) as Promise<Response<T>>;
		}

		throw 'Unhandled message ' + handlerName;
	}
}

export interface MessageSender {
	send<T extends MessageName>(name: T, payload: Payload<T>): void;
	request<T extends MessageName>(name: T, payload: Payload<T>): Promise<Response<T>>;
}
