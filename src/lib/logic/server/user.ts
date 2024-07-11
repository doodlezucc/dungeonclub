import { DISABLE_PERMISSIONS } from '$env/static/private';
import { type CampaignSnippet } from 'shared';
import { server } from './server';
import type { CampaignSession } from './session';
import { ConnectionSocket } from './socket';

export class User {
	readonly connection: ConnectionSocket;

	private _accountHash?: string;
	private _session?: CampaignSession;

	constructor(socket: ConnectionSocket) {
		this.connection = socket;
	}

	dispose() {
		console.log('dispose connection');
		this._session?.onLeave(this);
	}

	get accountHash() {
		return this._accountHash;
	}

	get loggedInAccountHash() {
		if (!this._accountHash) throw 'Not logged in';

		return this._accountHash;
	}

	get isLoggedIn() {
		return this._accountHash !== undefined;
	}

	get sessionOrNull() {
		return this._session;
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

	get visibleBoardIdOrNull() {
		return this.session.getVisibleBoardIdFor(this);
	}

	get visibleBoardId() {
		const result = this.visibleBoardIdOrNull;

		if (!result) throw 'No active board set for this user';

		return result;
	}

	onLogIn(accountHash: string) {
		this._accountHash = accountHash;
	}

	async enterSession(campaignId: string): Promise<CampaignSnippet> {
		const session = await server.sessionManager.enterSession(campaignId, this);
		this._session = session;

		return await session.loadSnippetFor(this);
	}
}
