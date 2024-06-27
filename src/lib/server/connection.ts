import type { HydratedCampaign, HydratedScene, IAccount } from '$lib/db/schemas';
import {
	MessageSocket,
	type Payload,
	type ResponseObject,
	type ServerHandledMessages,
	type ServerSentMessages
} from '$lib/net';
import type { HydratedDocument } from 'mongoose';
import type { WebSocket } from 'ws';
import { serverMessageHandler } from './socket';

export class Session {
	readonly campaign: HydratedCampaign;
	readonly isGM: boolean;
	private _visibleScene?: HydratedScene;

	constructor(campaign: HydratedCampaign, isGM: boolean) {
		this.campaign = campaign;
		this.isGM = isGM;
	}

	get activeSceneOrNull() {
		return this.campaign.scenes.id(this.campaign.activeScene) as HydratedScene | null;
	}

	get activeScene() {
		const result = this.activeSceneOrNull;

		if (!result) throw 'No active scene set in campaign';

		return result;
	}

	get visibleScene() {
		if (!this._visibleScene) {
			this._visibleScene = this.activeScene;
		}

		return this._visibleScene;
	}
}

export class Connection extends MessageSocket<ServerHandledMessages, ServerSentMessages> {
	private static utf8 = new TextDecoder('UTF-8');
	private webSocket: WebSocket;

	private _account?: HydratedDocument<IAccount>;
	private _session?: Session;

	constructor(webSocket: WebSocket) {
		super();
		this.webSocket = webSocket;

		webSocket.on('message', (data: Buffer) => {
			const dataAsString = Connection.utf8.decode(data);
			this.receiveIncomingMessage(dataAsString);
		});
	}

	get account() {
		return this._account;
	}

	get loggedInAccount() {
		if (!this._account) throw 'Not logged in';

		return this._account;
	}

	get isLoggedIn() {
		return this._account !== undefined;
	}

	get session() {
		if (!this._session) throw 'Not in a session';

		return this._session;
	}

	get sessionAsOwner() {
		const result = this.session;

		if (!result.isGM) throw 'Not in a session as GM';

		return result;
	}

	onLogIn(account: HydratedDocument<IAccount>) {
		this._account = account;
	}

	protected processMessage<T extends keyof ServerHandledMessages>(
		name: T,
		payload: Payload<ServerHandledMessages, T>
	): Promise<ResponseObject<ServerHandledMessages, T>> {
		return serverMessageHandler.handle<T>(name, payload, {
			dispatcher: this
		});
	}

	protected sendOutgoingMessage(encodedMessage: string): void {
		this.webSocket.send(encodedMessage);
	}
}
