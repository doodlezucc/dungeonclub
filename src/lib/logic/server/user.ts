import { DISABLE_PERMISSIONS } from '$env/static/private';
import { SelectBoard, SelectCampaign, type CampaignSnippet } from 'shared';
import { prisma, server } from './server';
import type { CampaignSession } from './session';
import { ConnectionSocket } from './socket';

export class User {
	readonly connection: ConnectionSocket;

	private _accountId?: string;
	private _activeBoardId?: string;
	private _session?: CampaignSession;

	constructor(socket: ConnectionSocket) {
		this.connection = socket;
	}

	dispose() {
		console.log('dispose connection');
		this._session?.onLeave(this);
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
		if (!result.isOwner(this)) throw 'Not in a session as GM';

		return result;
	}

	get activeBoardIdOrNull() {
		return this._activeBoardId;
	}

	get activeBoardId() {
		const result = this.activeBoardIdOrNull;

		if (!result) throw 'No active board set for this user';

		return result;
	}

	onLogIn(accountId: string) {
		this._accountId = accountId;
	}

	async enterSession(campaignId: string): Promise<CampaignSnippet> {
		this._session = server.sessionManager.enterSession(campaignId, this);

		const campaign = await prisma.campaign.findUniqueOrThrow({
			where: { id: campaignId },
			select: {
				...SelectCampaign,
				selectedBoardId: true
			}
		});

		const { selectedBoardId } = campaign;

		if (!selectedBoardId) {
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
}
