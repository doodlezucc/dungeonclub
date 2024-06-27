import { MessageHandler, type CategoryHandlers, type ServerHandledMessages } from '$lib/net';
import { Connection } from './connection';
import { accountHandler } from './handlers/account';
import { tokensHandler } from './handlers/tokens';

export interface HandlerOptions {
	dispatcher: Connection;
}

export type CategoryHandler<C> = CategoryHandlers<C, ServerHandledMessages, HandlerOptions>;

export class ServerMessageHandler extends MessageHandler<ServerHandledMessages, HandlerOptions> {
	account = accountHandler;

	tokens = tokensHandler;
}

export const serverMessageHandler = new ServerMessageHandler();
