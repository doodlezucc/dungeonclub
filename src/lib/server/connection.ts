import type { ICampaign } from '$lib/db/schemas/campaign';
import type { MessageSender, Payload, Response } from '$lib/messages/handling';
import type { MessageName } from '$lib/messages/messages';
import type { HydratedDocument } from 'mongoose';
import { serverMessageHandler } from './socket';

export class Session {
	campaign: HydratedDocument<ICampaign>;

	constructor(campaign: HydratedDocument<ICampaign>) {
		this.campaign = campaign;
	}
}

export class Connection implements MessageSender {
	session?: Session;

	handle<T extends MessageName>(name: T, payload: Payload<T>): Promise<Response<T>> {
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
