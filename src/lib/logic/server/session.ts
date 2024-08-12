import { SelectBoard, SelectCampaign } from 'shared';
import { prisma } from './server';
import type { User } from './user';

export class SessionManager {
	private readonly openSessions = new Map<string, CampaignSession>();

	async enterSession(campaignId: string, user: User): Promise<CampaignSession> {
		const campaignSession = this.openSessions.get(campaignId);

		if (campaignSession) {
			campaignSession.onJoin(user);
			return campaignSession;
		} else {
			const newSession = await CampaignSession.load(user, campaignId);
			this.openSessions.set(campaignId, newSession);
			return newSession;
		}
	}
}

export class CampaignSession {
	readonly campaignId: string;

	users: User[] = [];
	host: User | null;

	constructor(hostedBy: User, campaignId: string) {
		this.host = hostedBy;

		this.campaignId = campaignId;

		this.onJoin(hostedBy);
	}

	static async load(hostedBy: User, campaignId: string) {
		await prisma.campaign.findUniqueOrThrow({
			where: { id: campaignId }
		});

		return new CampaignSession(hostedBy, campaignId);
	}

	getPeerUsersOf(user: User) {
		return this.users.filter((peer) => peer != user);
	}

	async loadSnippetFor(user: User) {
		const campaign = await prisma.campaign.findUniqueOrThrow({
			where: { id: this.campaignId },
			select: SelectCampaign
		});

		user.sessionConnection.visibleBoardIdOrNull = campaign.selectedBoardId;

		if (!campaign.selectedBoardId) {
			return campaign;
		}

		const visibleBoard = await prisma.board.findUniqueOrThrow({
			where: { id: campaign.selectedBoardId },
			select: SelectBoard
		});

		return {
			...campaign,
			selectedBoard: visibleBoard
		};
	}

	onJoin(user: User) {
		this.users.push(user);
		console.log('User joined');
	}

	onLeave(disconnectedUser: User) {
		if (disconnectedUser == this.host) {
			this.host = null;
		}

		this.users = this.users.filter((user) => user != disconnectedUser);
		console.log('User left');
	}

	isOwner(user: User): boolean {
		return this.host != null && this.host == user;
	}
}

export class SessionConnection {
	visibleBoardIdOrNull: string | null = null;

	constructor(readonly session: CampaignSession) {}

	get visibleBoardId() {
		if (!this.visibleBoardIdOrNull) throw 'Not on any board';

		return this.visibleBoardIdOrNull!;
	}
}
