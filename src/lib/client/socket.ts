import {
	MessageSocket,
	type ClientHandledMessages,
	type ClientSentMessages,
	type ResponseObject
} from '$lib/net';

export class ClientSocket extends MessageSocket<ClientHandledMessages, ClientSentMessages> {
	private readonly webSocket: WebSocket;

	constructor(webSocket: WebSocket) {
		super();
		this.webSocket = webSocket;
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
