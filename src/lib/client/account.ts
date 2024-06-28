import type { CampaignCardSnippet } from '$lib/net/snippets/campaign';

export class Account {
	email: string;
	campaigns: CampaignCardSnippet[];

	constructor(email: string, campaigns: CampaignCardSnippet[]) {
		this.email = email;
		this.campaigns = campaigns;
	}
}
