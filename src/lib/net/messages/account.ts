import type { ICampaign } from '$lib/db/schemas';
import type { AccountSnippet } from '../snippets/account';
import type { CampaignCardSnippet } from '../snippets/campaign';
import type { DefinePrivateRequest } from './messages';

export interface AccountMessageCategory {
	login: DefinePrivateRequest<
		{
			email: string;
			password: string;
		},
		{
			account: AccountSnippet;
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

	campaignEdit: DefinePrivateRequest<
		{
			id: string;
			name: string;
		},
		CampaignCardSnippet
	>;
}
