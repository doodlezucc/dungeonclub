import { Schema, Types } from 'mongoose';
import { model } from './util';

export interface IAccount {
	email: string;
	password: string;
	campaigns: Types.ObjectId[];
}

export const AccountSchema = new Schema<IAccount>({
	email: { type: String, required: true },
	password: { type: String, required: true },
	campaigns: [{ type: Types.ObjectId, ref: 'Campaign' }]
});

export const Account = model('Account', AccountSchema);
