import { expect, it } from 'vitest';
import { type Payload, type Response } from './handling';
import type {
	AllMessages,
	ClientHandledMessages,
	ClientSentMessages,
	ServerHandledMessages,
	ServerSentMessages
} from './messages';
import { MessageSocket } from './socket';

it('sends and receives', async () => {
	const response = await testClient.request('tokenCreate', {
		position: {
			x: 0.5,
			y: 2.5
		},
		tokenDefinition: 'someTokenDefId'
	});

	expect(response).toEqual({
		token: {
			label: 'Test Label',
			position: {
				x: 0.5,
				y: 2.5
			}
		}
	} as Response<AllMessages, 'tokenCreate'>);
});

class TestClient extends MessageSocket<ClientHandledMessages, ClientSentMessages> {
	protected async processMessage<T extends keyof ClientHandledMessages>(): Promise<
		Response<ClientHandledMessages, T>
	> {
		throw 'Message processing not implemented on client side';
	}

	protected sendOutgoingMessage(encodedMessage: string): void {
		testServer.receiveIncomingMessage(encodedMessage);
	}
}

class TestServer extends MessageSocket<ServerHandledMessages, ServerSentMessages> {
	protected async processMessage<T extends keyof ServerHandledMessages>(
		name: T,
		payload: Payload<ServerHandledMessages, T>
	): Promise<Response<ServerHandledMessages, T>> {
		console.log(`server processes ${name} with payload`, payload);

		if (name === 'tokenCreate') {
			const request = payload as Payload<AllMessages, 'tokenCreate'>;

			return {
				token: {
					label: 'Test Label',
					position: request.position
				}
			} as Response<AllMessages, 'tokenCreate'> as Response<ServerHandledMessages, T>;
		}

		throw 'Message not implemented';
	}

	protected sendOutgoingMessage(encodedMessage: string): void {
		testClient.receiveIncomingMessage(encodedMessage);
	}
}

const testClient = new TestClient();
const testServer = new TestServer();
