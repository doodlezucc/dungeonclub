import {
	MessageHandler,
	MessageSocket,
	type CategoryHandlers,
	type Payload,
	type ResponseObject,
	type ServerHandledMessages,
	type ServerSentMessages
} from 'shared';
import type { WebSocket } from 'ws';
import { accountHandler } from './handlers/account-handler';
import { boardHandler } from './handlers/board-handler';
import { campaignHandler } from './handlers/campaign-handler';
import { User } from './user';

export interface HandlerOptions {
	dispatcher: User;
}

export type CategoryHandler<C> = CategoryHandlers<C, ServerHandledMessages, HandlerOptions>;

export class ServerMessageHandler extends MessageHandler<ServerHandledMessages, HandlerOptions> {
	account = accountHandler;
	board = boardHandler;
	campaign = campaignHandler;
}

export const serverMessageHandler = new ServerMessageHandler();

export class ConnectionSocket extends MessageSocket<ServerHandledMessages, ServerSentMessages> {
	private static utf8 = new TextDecoder('UTF-8');

	readonly connection: User;
	private webSocket: WebSocket;

	constructor(webSocket: WebSocket) {
		super();
		this.connection = new User(this);
		this.webSocket = webSocket;

		webSocket.on('message', (data: Buffer) => {
			const dataAsString = ConnectionSocket.utf8.decode(data);
			this.receiveIncomingMessage(dataAsString);
		});
	}

	dispose() {
		this.connection.dispose();
	}

	protected processMessage<T extends keyof ServerHandledMessages>(
		name: T,
		payload: Payload<ServerHandledMessages, T>
	): Promise<ResponseObject<ServerHandledMessages, T>> {
		return serverMessageHandler.handle<T>(name, payload, {
			dispatcher: this.connection
		});
	}

	protected sendOutgoingMessage(encodedMessage: string): void {
		this.webSocket.send(encodedMessage);
	}
}
