import { expect, it } from 'vitest';
import type {
	AllMessages,
	ClientHandledMessages,
	ClientSentMessages,
	Payload,
	Response,
	ResponseObject,
	ServerHandledMessages,
	ServerSentMessages
} from '../messages';
import { publicResponse } from './handling';
import { MessageSocket } from './socket';

it('sends and receives', async () => {
	const response = await testClient.request('tokenCreate', {
		boardId: 'boardid',
		position: {
			x: 0.5,
			y: 2.5
		},
		tokenTemplate: 'someTokenDefId'
	});

	expect(response).toEqual({
		boardId: 'boardid',
		token: {
			id: 'new uuid',
			templateId: 'someTokenDefId',
			label: 'Test Label',
			conditions: [],
			invisible: false,
			size: 1,
			x: 0.5,
			y: 2.5
		}
	} as Response<AllMessages, 'tokenCreate'>);
});

class TestClient extends MessageSocket<ClientHandledMessages, ClientSentMessages> {
	protected async processMessage<T extends keyof ClientHandledMessages>(): Promise<
		ResponseObject<ClientHandledMessages, T>
	> {
		throw 'Message processing not implemented on client side';
	}

	protected sendOutgoingMessage(encodedMessage: string): void {
		testServer.receiveIncomingMessage(encodedMessage);
	}

	public receiveIncomingMessage(encodedMessage: string): void {
		return super.receiveIncomingMessage(encodedMessage);
	}
}

type _ServerHandled = Pick<ServerHandledMessages, 'tokenCreate'>;

class TestServer extends MessageSocket<_ServerHandled, ServerSentMessages> {
	protected async processMessage<T extends keyof _ServerHandled>(
		name: T,
		payload: Payload<_ServerHandled, T>
	): Promise<ResponseObject<_ServerHandled, T>> {
		console.log(`server processes ${name} with payload`, payload);

		const { boardId, position, tokenTemplate: tokenDefinition } = payload;

		return publicResponse(<Response<_ServerHandled, 'tokenCreate'>>{
			boardId,
			token: {
				id: 'new uuid',
				templateId: tokenDefinition,
				label: 'Test Label',
				conditions: [],
				invisible: false,
				size: 1,
				...position
			}
		}) as ResponseObject<_ServerHandled, T>;
	}

	protected sendOutgoingMessage(encodedMessage: string): void {
		testClient.receiveIncomingMessage(encodedMessage);
	}

	public receiveIncomingMessage(encodedMessage: string): void {
		return super.receiveIncomingMessage(encodedMessage);
	}
}

const testClient = new TestClient();
const testServer = new TestServer();
