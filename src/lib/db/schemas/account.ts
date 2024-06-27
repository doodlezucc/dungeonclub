import { Schema, type HydratedDocument } from 'mongoose';
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

export type HydratedAccount = HydratedDocument<
	IAccount,
	{
		campaigns: DocumentArray<ICampaign>;
	}
>;

export const Account = modelWithHierarchy<HydratedAccount>('Account', AccountSchema);
