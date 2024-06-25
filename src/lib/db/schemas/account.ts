import { Schema } from 'mongoose';
import { CampaignSchema, type ICampaign } from './campaign';
import { model } from './util/model-reloading';

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

export const Account = model('Account', AccountSchema);
