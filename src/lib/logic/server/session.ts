import type { User } from './user';

export class SessionManager {
	private readonly openSessions = new Map<string, CampaignSession>();

	enterSession(campaignId: string, user: User): CampaignSession {
		const campaignSession = this.openSessions.get(campaignId);

		if (campaignSession) {
			campaignSession.onJoin(user);
			return campaignSession;
		} else {
			const newSession = new CampaignSession(campaignId, user);
			this.openSessions.set(campaignId, newSession);
			return newSession;
		}
	}
}

export class CampaignSession {
	private users: User[] = [];
	private host: User | null;

	readonly campaignId: string;

	constructor(campaignId: string, hostedBy: User) {
		this.campaignId = campaignId;
		this.host = hostedBy;
		this.onJoin(hostedBy);
	}

	onJoin(user: User) {
		this.users.push(user);
		console.log('User joined');
	}

	onLeave(disconnectedUser: User) {
		this.users = this.users.filter((user) => user != disconnectedUser);
		console.log('User left');
	}

	isOwner(user: User): boolean {
		return this.host != null && this.host == user;
	}
}
