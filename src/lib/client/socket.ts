import { PUBLIC_WEBSOCKET_URL } from '$env/static/public';
import {
	MessageSocket,
	type ClientHandledMessages,
	type ClientSentMessages,
	type ResponseObject
} from '$lib/net';
import { writable } from 'svelte/store';
import { Account } from './account';

export const account = writable<Account | null>(null);

export class ClientSocket extends MessageSocket<ClientHandledMessages, ClientSentMessages> {
	private readonly webSocket: WebSocket;
	private _accountEmail?: string;

	constructor() {
		super({ unready: true });

		const ws = new WebSocket(PUBLIC_WEBSOCKET_URL);
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

		this._accountEmail = emailAddress;
		account.set(new Account(emailAddress, response.account.campaigns));

		return response;
	}

	get accountEmail() {
		return this._accountEmail;
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
