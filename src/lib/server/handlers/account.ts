import { Account } from '$lib/db/schemas';
import type { AccountMessageCategory } from '$lib/net';
import type { CategoryHandler } from '../socket';

export const accountHandler: CategoryHandler<AccountMessageCategory> = {
	handleLogin: async ({ email, password }) => {
		const account = await Account.findOne({ email, password });

		if (!account) {
			throw 'No account with this email and password exists';
		}

		return {
			campaigns: account.campaigns
		};
	},

	handleAccountCreate: async ({ email, password }) => {
		const account = await Account.create({
			email,
			password,
			campaigns: []
		});

		console.log('Created account', account);

		return true;
	}
};
