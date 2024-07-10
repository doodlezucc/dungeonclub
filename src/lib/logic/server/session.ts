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
	private users: User[] = [];
	private host: User | null;

	readonly campaignId: string;
	private selectedBoardId: string | null;
	private hostBoardId: string | null;

	constructor(hostedBy: User, campaignId: string, selectedBoardId: string | null) {
		this.host = hostedBy;

		this.campaignId = campaignId;
		this.selectedBoardId = selectedBoardId;
		this.hostBoardId = selectedBoardId;

		this.onJoin(hostedBy);
	}

	static async load(hostedBy: User, campaignId: string) {
		const { selectedBoardId } = await prisma.campaign.findUniqueOrThrow({
			where: { id: campaignId },
			select: {
				selectedBoardId: true
			}
		});

		return new CampaignSession(hostedBy, campaignId, selectedBoardId);
	}

	getVisibleBoardIdFor(user: User) {
		if (user == this.host) {
			return this.hostBoardId;
		} else {
			return this.selectedBoardId;
		}
	}

	getPeerUsersOf(user: User) {
		return this.users.filter((peer) => peer != user);
	}

	async loadSnippetFor(user: User) {
		const campaign = await prisma.campaign.findUniqueOrThrow({
			where: { id: this.campaignId },
			select: {
				...SelectCampaign
			}
		});

		const visibleBoardId = this.getVisibleBoardIdFor(user);

		if (!visibleBoardId) {
			return campaign;
		}

		const visibleBoard = await prisma.board.findUniqueOrThrow({
			where: { id: visibleBoardId },
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
