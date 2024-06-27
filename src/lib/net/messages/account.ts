import type { ICampaign } from '$lib/db/schemas';
import type { DefinePrivateRequest } from './messages';

export interface AccountMessageCategory {
	login: DefinePrivateRequest<
		{
			email: string;
			password: string;
		},
		{
			campaigns: ICampaign[];
		}
	>;

	accountCreate: DefinePrivateRequest<
		{
			email: string;
			password: string;
		},
		true
	>;

	campaignCreate: DefinePrivateRequest<
		{
			name: string;
		},
		ICampaign
	>;
}
