import type { CampaignSnippet } from '$lib/net/snippets/campaign';

export class Account {
	email: string;
	campaigns: CampaignSnippet[];

	constructor(email: string, campaigns: CampaignSnippet[]) {
		this.email = email;
		this.campaigns = campaigns;
	}
}
