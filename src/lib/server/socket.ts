import { MessageHandler, type CategoryHandlers, type ServerHandledMessages } from '$lib/net';
import { Connection } from './connection';
import { accountHandler } from './handlers/account-handler';
import { boardHandler } from './handlers/board-handler';
import { campaignHandler } from './handlers/campaign-handler';

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
