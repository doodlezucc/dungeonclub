import {
	MessageSocket,
	type ClientHandledMessages,
	type ClientSentMessages,
	type ResponseObject
} from '$lib/net';
import { readable, writable } from 'svelte/store';
import { Account } from './account';
import { RestConnection } from './rest';
import { Session } from './session';

export const account = writable<Account | null>(null);
export const session = writable<Session | null>(null);
export const rest = readable(new RestConnection());

export class ClientSocket extends MessageSocket<ClientHandledMessages, ClientSentMessages> {
	private readonly webSocket: WebSocket;

	constructor() {
		super({ unready: true });

		const ws = connectToWebSocketServer();

		ws.addEventListener('open', () => {
			console.log('Connection opened!');
			this.markAsReady();
		});
		ws.addEventListener('message', (ev) => {
			this.receiveIncomingMessage(ev.data);
		});
		ws.addEventListener('error', (ev) => {
			console.error('WebSocket error!', ev);
		});
		ws.addEventListener('close', (ev) => {
			console.log('Connection closed!', ev);
		});
		this.webSocket = ws;
	}

	async logIn(emailAddress: string, password: string) {
		const response = await this.request('login', {
			email: emailAddress,
			password: password
		});

		account.set(
			new Account(response.account.accessToken, emailAddress, response.account.campaigns)
		);

		return response;
	}

	protected processMessage<T extends keyof ClientHandledMessages>(): Promise<
		ResponseObject<ClientHandledMessages, T>
	> {
		throw new Error('Method not implemented.');
	}

	protected sendOutgoingMessage(encodedMessage: string): void {
		this.webSocket.send(encodedMessage);
	}
}

function connectToWebSocketServer() {
	const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
	return new WebSocket(`${protocol}//${window.location.host}/websocket`);
}
