import type {
	IForward,
	IMessage,
	IResponse,
	MarkedAsEvent,
	TokensMessageCategory
} from '../messages';
import type { AccountMessageCategory } from '../messages/account';

export type AsPayload<T> = T extends IMessage<infer P> ? P : never;
export type Payload<S, T extends keyof S> = AsPayload<S[T]>;

export type AsResponseObject<T> = T extends IForward<infer F> & IResponse<infer R>
	? {
			forwardedResponse: F;
			response: R;
		}
	: T extends IForward<infer F>
		? {
				forwardedResponse: F;
			}
		: T extends IResponse<infer R>
			? R
			: void;
export type ResponseObject<S, T extends keyof S> = AsResponseObject<S[T]>;

export type AsResponse<T> = T extends IResponse<infer R> ? R : void;
export type Response<S, T extends keyof S> = AsResponse<S[T]>;

export type AsForwarded<T> = T extends IForward<infer F> ? F : void;
export type Forwarded<S, T extends keyof S> = AsForwarded<S[T]>;

export type PickStringKeysOfIntersection<A, B> = Pick<A, keyof A & keyof B & string>;
export type StringKeysOf<A, B> = keyof PickStringKeysOfIntersection<A, B>;

export type EventHandlerName<K extends string> = `on${Capitalize<K>}`;
export type HandlerName<K extends string> = `handle${Capitalize<K>}`;

export type CategoryHandlers<CATEGORY, HANDLED, OPTIONS> = {
	[K in StringKeysOf<CATEGORY, HANDLED> as HANDLED[K] extends MarkedAsEvent
		? EventHandlerName<K>
		: HandlerName<K>]: HANDLED[K] extends MarkedAsEvent
		? (payload: Forwarded<CATEGORY, K>, options: OPTIONS) => void
		: (payload: Payload<CATEGORY, K>, options: OPTIONS) => Promise<ResponseObject<CATEGORY, K>>;
};

export abstract class MessageHandler<HANDLED, OPTIONS> {
	abstract tokens: CategoryHandlers<TokensMessageCategory, HANDLED, OPTIONS>;
	abstract account: CategoryHandlers<AccountMessageCategory, HANDLED, OPTIONS>;

	private _allHandlers: CategoryHandlers<unknown, HANDLED, OPTIONS>[] | undefined;
	get allHandlers() {
		return (this._allHandlers ??= [this.tokens, this.account]);
	}

	handle<T extends keyof HANDLED & string>(
		name: T,
		payload: Payload<HANDLED, T>,
		options: OPTIONS
	): Promise<Response<HANDLED, T>> {
		const nameCapitalized = name.substring(0, 1).toUpperCase() + name.substring(1);
		const handlerName = `handle${nameCapitalized}`;

		return this.runHandler(handlerName as HandlerName<T>, payload, options);
	}

	runHandler<T extends keyof HANDLED & string>(
		handlerName: HandlerName<T>,
		payload: Payload<HANDLED, T>,
		options: OPTIONS
	): Promise<Response<HANDLED, T>> {
		const handlerNameCasted = handlerName as keyof CategoryHandlers<unknown, HANDLED, OPTIONS>;

		for (const handlerCategory of this.allHandlers) {
			if (handlerName in handlerCategory) {
				const handle = handlerCategory[handlerNameCasted] as (
					payload: Payload<HANDLED, T>,
					options: OPTIONS
				) => Promise<Response<HANDLED, T>>;

				return handle(payload, options);
			}
		}

		throw 'Unhandled message ' + handlerName;
	}
}

export interface MessageSender<SENT> {
	send<T extends keyof SENT>(name: T, payload: Payload<SENT, T>): void;
	request<T extends keyof SENT>(name: T, payload: Payload<SENT, T>): Promise<Response<SENT, T>>;
}

export function publicResponse<R>(response: R) {
	return {
		forwardedResponse: response,
		response: response
	};
}
