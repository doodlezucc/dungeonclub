import type { ICampaign } from '$lib/db/schemas/campaign';
import type { SendMessage } from '$lib/messages/codec';
import type { MessageSender, Payload, Response } from '$lib/messages/handling';
import type { MessageName } from '$lib/messages/messages';
import type { HydratedDocument } from 'mongoose';
import type { WebSocket } from 'ws';
import { serverMessageHandler } from './socket';

export class Session {
	campaign: HydratedDocument<ICampaign>;

	constructor(campaign: HydratedDocument<ICampaign>) {
		this.campaign = campaign;
	}
}

export class Connection implements MessageSender {
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

	handle<T extends MessageName>(message: SendMessage<T>): Promise<Response<T>> {
		const { name, payload } = message;

		return serverMessageHandler.handle(name, payload, { dispatcher: this });
	}

	send<T extends MessageName>(name: T, payload: Payload<T>): void {
		console.log(`[server -> ${this}] ${name} with payload: ${payload}`);
	}

	async request<T extends MessageName>(name: T, payload: Payload<T>): Promise<Response<T>> {
		console.log(`[server -> ${this}] REQUEST ${name} with payload: ${payload}`);
		await new Promise((res) => setTimeout(res, 1000));

		return {} as Response<T>;
	}
}
