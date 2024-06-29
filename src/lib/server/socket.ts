import { MessageHandler, type CategoryHandlers, type ServerHandledMessages } from '$lib/net';
import { Connection } from './connection';
import { accountHandler } from './handlers/accountHandler';
import { boardHandler } from './handlers/boardHandler';
import { campaignHandler } from './handlers/campaignHandler';

export interface HandlerOptions {
	dispatcher: Connection;
}

export type CategoryHandler<C> = CategoryHandlers<C, ServerHandledMessages, HandlerOptions>;

export class ServerMessageHandler extends MessageHandler<ServerHandledMessages, HandlerOptions> {
	account = accountHandler;
	board = boardHandler;
	campaign = campaignHandler;
}

export const serverMessageHandler = new ServerMessageHandler();
