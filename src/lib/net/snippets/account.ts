import type { CampaignCardSnippet } from './campaign';

export interface AccountSnippet {
	accessToken: string;
	email: string;
	campaigns: CampaignCardSnippet[];
}
