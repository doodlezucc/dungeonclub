export class Account {
	email: string;
	campaigns: CampaignSnippet[];

	constructor(email: string, campaigns: CampaignSnippet[]) {
		this.email = email;
		this.campaigns = campaigns;
	}
}

export interface CampaignSnippet {
	id: string;
	name: string;
	createdAt: Date;
}
