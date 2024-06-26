import type { TokensMessageCategory } from './tokens';

export interface RequestMessage<A, B> {
	request: A;
	response: B;
}

export type ID = string;

export type AllMessages = TokensMessageCategory;
export type MessageName = keyof AllMessages;
