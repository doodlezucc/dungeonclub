import { Account, type ICampaign } from '$lib/db/schemas';
import type { AccountMessageCategory } from '$lib/net';
import type { CategoryHandler } from '../socket';

export const accountHandler: CategoryHandler<AccountMessageCategory> = {
	handleLogin: async ({ email, password }, { dispatcher }) => {
		if (dispatcher.isLoggedIn) {
			throw 'Already logged in';
		}

		const account = await Account.findOne({ email, password })
			.populate('campaigns', ['id', 'name', 'createdAt'])
			.exec();

		if (!account) {
			throw 'No account with this email and password exists';
		}

		dispatcher.onLogIn(account);

		return {
			account: {
				email,
				campaigns: account.campaigns.map((ref) => {
					const { id, name, createdAt } = ref as unknown as ICampaign;
					return {
						id,
						name,
						createdAt
					};
				})
			}
		};
	},

	handleAccountCreate: async ({ email, password }, { dispatcher }) => {
		if (await Account.exists({ email: email })) {
			throw 'An account with this email address already exists';
		}

		const account = await Account.create({
			email,
			password,
			campaigns: []
		});

		console.log('Created account', account);
		dispatcher.onLogIn(account);

		return {
			account: {
				email,
				campaigns: []
			}
		};
	}
};
