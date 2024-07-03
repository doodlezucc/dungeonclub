import { DISABLE_PERMISSIONS } from '$env/static/private';
import {
	MessageSocket,
	SelectBoard,
	SelectCampaign,
	type CampaignSnippet,
	type Payload,
	type ResponseObject,
	type ServerHandledMessages,
	type ServerSentMessages
} from '$lib/net';
import type { Board } from '@prisma/client';
import type { WebSocket } from 'ws';
import { prisma } from './server';
import { serverMessageHandler } from './socket';

export class Session {
	readonly campaignId: string;
	readonly isGM: boolean;
	private _visibleBoard?: Board;

	constructor(campaignId: string, isGM: boolean) {
		this.campaignId = campaignId;
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

interface EnterSessionOptions {
	isGM: boolean;
}

export class Connection extends MessageSocket<ServerHandledMessages, ServerSentMessages> {
	private static utf8 = new TextDecoder('UTF-8');
	private webSocket: WebSocket;

	private _accountId?: string;
	private _session?: Session;

	constructor(webSocket: WebSocket) {
		super();
		this.webSocket = webSocket;

		webSocket.on('message', (data: Buffer) => {
			const dataAsString = Connection.utf8.decode(data);
			this.receiveIncomingMessage(dataAsString);
		});
	}

	get accountId() {
		return this._accountId;
	}

	get loggedInAccountId() {
		if (!this._accountId) throw 'Not logged in';

		return this._accountId;
	}

	get isLoggedIn() {
		return this._accountId !== undefined;
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

	onLogIn(accountId: string) {
		this._accountId = accountId;
	}

	async enterSession(campaignId: string, { isGM }: EnterSessionOptions): Promise<CampaignSnippet> {
		const campaign = await prisma.campaign.findUniqueOrThrow({
			where: { id: campaignId },
			select: {
				...SelectCampaign,
				selectedBoardId: true
			}
		});

		const { selectedBoardId } = campaign;

		if (!selectedBoardId) {
			this._session = new Session(campaignId, isGM);
			return campaign;
		}

		const selectedBoard = await prisma.board.findUniqueOrThrow({
			where: { id: selectedBoardId },
			select: SelectBoard
		});

		return {
			...campaign,
			selectedBoard: selectedBoard
		};
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
