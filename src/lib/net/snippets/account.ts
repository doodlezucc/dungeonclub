import type { CampaignCardSnippet } from './campaign';

export interface AccountSnippet {
	email: string;
	campaigns: CampaignCardSnippet[];
}
