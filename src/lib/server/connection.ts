import type { ICampaign } from '$lib/db/schemas/campaign';
import type { ServerHandledMessages, ServerSentMessages } from '$lib/messages';
import type { MessageSender, Payload, Response, SendMessage } from '$lib/socket';
import type { HydratedDocument } from 'mongoose';
import type { WebSocket } from 'ws';
import { serverMessageHandler } from './socket';

export class Session {
	campaign: HydratedDocument<ICampaign>;

	constructor(campaign: HydratedDocument<ICampaign>) {
		this.campaign = campaign;
	}
}

export class Connection implements MessageSender<ServerSentMessages> {
	private static utf8 = new TextDecoder('UTF-8');
	private webSocket: WebSocket;

	session?: Session;

	constructor(webSocket: WebSocket) {
		this.webSocket = webSocket;

		webSocket.on('message', (data: Buffer) => {
			const dataAsString = Connection.utf8.decode(data);

			console.log('RECEIVED', dataAsString);
		});
	}

	handle<T extends keyof ServerHandledMessages>(
		message: SendMessage<ServerHandledMessages, T>
	): Promise<Response<ServerHandledMessages, T>> {
		const { name, payload } = message;

		return serverMessageHandler.handle(name, payload, { dispatcher: this });
	}

	send<T extends keyof ServerSentMessages>(name: T, payload: Payload<ServerSentMessages, T>): void {
		console.log(`[server -> ${this}] ${name} with payload: ${payload}`);
	}

	async request<T extends keyof ServerSentMessages>(
		name: T,
		payload: Payload<ServerSentMessages, T>
	): Promise<Response<ServerSentMessages, T>> {
		console.log(`[server -> ${this}] REQUEST ${name} with payload: ${payload}`);
		await new Promise((res) => setTimeout(res, 1000));

		return {} as Response<ServerSentMessages, T>;
	}
}
