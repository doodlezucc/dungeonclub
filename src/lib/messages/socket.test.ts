import { expect, it } from 'vitest';
import type { Payload, Response } from './handling';
import type { MessageName } from './messages';
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
	} as Response<'tokenCreate'>);
});

class TestClient extends MessageSocket {
	protected async processMessage<T extends MessageName>(): Promise<Response<T>> {
		throw 'Message processing not implemented on client side';
	}

	protected sendOutgoingMessage(encodedMessage: string): void {
		testServer.receiveIncomingMessage(encodedMessage);
	}
}

class TestServer extends MessageSocket {
	protected async processMessage<T extends MessageName>(
		name: T,
		payload: Payload<T>
	): Promise<Response<T>> {
		console.log(`server processes ${name} with payload`, payload);

		if (name === 'tokenCreate') {
			const request = payload as Payload<'tokenCreate'>;

			return {
				token: {
					label: 'Test Label',
					position: request.position
				}
			} as Response<'tokenCreate'> as Response<T>;
		}

		throw 'Message not implemented';
	}

	protected sendOutgoingMessage(encodedMessage: string): void {
		testClient.receiveIncomingMessage(encodedMessage);
	}
}

const testClient = new TestClient();
const testServer = new TestServer();
