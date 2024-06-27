import type { TokensMessageCategory } from './tokens';

export interface IMessage<P> {
	payload: P;
}
export interface IMessageForServer<P> extends IMessage<P> {
	payloadForServer: P;
}
export interface IMessageForClient<P> extends IMessage<P> {
	payloadForClient: P;
}
export interface IResponse<R> {
	response: R;
}

export interface IForward<F> {
	forwardedPayload: F;
}

export interface DefineSend<P, F> extends IMessageForServer<P>, IForward<F> {}
export type DefineSendAndForward<P> = DefineSend<P, P>;

export interface DefineRequest<P, R, F> extends IMessageForServer<P>, IResponse<R>, IForward<F> {}
export type DefineRequestWithPublicResponse<P, R> = DefineRequest<P, R, R>;

export type ID = string;

export type AllMessages = TokensMessageCategory;

export type PickMessages<T> = {
	[K in keyof AllMessages as AllMessages[K] extends T ? K : never]: AllMessages[K];
};
export type PickForwardedMessages<S> = {
	[K in keyof S as S[K] extends IForward<unknown> ? K : never]: S[K] extends IForward<infer F>
		? F
		: S[K];
};

export type ServerSentMessages = PickMessages<IMessageForClient<unknown>>;
export type ServerHandledMessages = PickMessages<IMessageForServer<unknown>>;

export type ClientSentMessages = ServerHandledMessages;
export type ClientHandledMessages = PickMessages<IMessageForClient<unknown>> & ClientHandledEvents;

export type ClientHandledEvents = PickForwardedMessages<ClientSentMessages>;
