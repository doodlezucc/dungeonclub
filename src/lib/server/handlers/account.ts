import { Account, Campaign } from '$lib/db/schemas';
import type { AccountMessageCategory } from '$lib/net';
import type { CategoryHandler } from '../socket';

export const accountHandler: CategoryHandler<AccountMessageCategory> = {
	handleLogin: async ({ email, password }, { dispatcher }) => {
		if (dispatcher.isLoggedIn) {
			throw 'Already logged in';
		}

		const account = await Account.findOne({ email, password });

		if (!account) {
			throw 'No account with this email and password exists';
		}

		dispatcher.onLogIn(account);

		return {
			campaigns: account.campaigns
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

		return true;
	},

	handleCampaignCreate: async ({ name }, { dispatcher }) => {
		const account = dispatcher.loggedInAccount;

		const newCampaign = await Campaign.create({
			name,
			id: generateCampaignID()
		});

		await account.updateOne({
			$push: { campaigns: newCampaign }
		});

		return newCampaign;
	}
};

function generateCampaignID() {
	return 'testcampaign';
}
