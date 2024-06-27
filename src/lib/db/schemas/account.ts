import { Schema } from 'mongoose';
import { CampaignSchema, type ICampaign } from './campaign';
import { modelWithHierarchy, type DocumentArray } from './util';

export interface IAccount {
	email: string;
	password: string;
	campaigns: ICampaign[];
}

export const AccountSchema = new Schema<IAccount>({
	email: { type: String, required: true },
	password: { type: String, required: true },
	campaigns: [CampaignSchema]
});

export const Account = modelWithHierarchy<
	IAccount,
	{
		campaigns: DocumentArray<ICampaign>;
	}
>('Account', AccountSchema);
