import { DISABLE_PERMISSIONS } from '$env/static/private';
import {
	MessageSocket,
	type Payload,
	type ResponseObject,
	type ServerHandledMessages,
	type ServerSentMessages
} from '$lib/net';
import type { Account, Board, Campaign } from '@prisma/client';
import type { WebSocket } from 'ws';
import { serverMessageHandler } from './socket';

export class Session {
	readonly campaign: Campaign;
	readonly isGM: boolean;
	private _visibleBoard?: Board;

	constructor(campaign: Campaign, isGM: boolean) {
		this.campaign = campaign;
		this.isGM = isGM;
	}

	get activeBoardOrNull() {
		return null;
		// return this.campaign.boards.id(this.campaign.activeBoard) as HydratedBoard | null;
	}

	get activeBoard() {
		const result = this.activeBoardOrNull;

		if (!result) throw 'No active board set in campaign';

		return result;
	}

	get visibleBoard() {
		if (!this._visibleBoard) {
			this._visibleBoard = this.activeBoard;
		}

		return this._visibleBoard;
	}
}

export class Connection extends MessageSocket<ServerHandledMessages, ServerSentMessages> {
	private static utf8 = new TextDecoder('UTF-8');
	private webSocket: WebSocket;

	private _account?: Account;
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

		if (DISABLE_PERMISSIONS) return result;
		if (!result.isGM) throw 'Not in a session as GM';

		return result;
	}

	onLogIn(account: Account) {
		this._account = account;
	}

	onEnterSession(session: Session) {
		this._session = session;
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
