import type { CampaignSnippet } from './campaign';

export interface AccountSnippet {
	email: string;
	campaigns: CampaignSnippet[];
}
