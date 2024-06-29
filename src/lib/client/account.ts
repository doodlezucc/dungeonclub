import type { CampaignCardSnippet } from '$lib/net/snippets/campaign';

export class Account {
	accessToken: string;
	email: string;
	campaigns: CampaignCardSnippet[];

	constructor(accessToken: string, email: string, campaigns: CampaignCardSnippet[]) {
		this.accessToken = accessToken;
		this.email = email;
		this.campaigns = campaigns;
	}
}
