import { Account, Campaign, type ICampaign } from '$lib/db/schemas';
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
	},

	handleCampaignEdit: async ({ id, name }, { dispatcher }) => {
		const campaign = await Campaign.findOne({ id });

		if (!campaign) {
			throw 'Campaign not found';
		}

		const isOwnedByAccount = dispatcher.loggedInAccount.campaigns.some((owned) =>
			owned._id.equals(campaign._id)
		);

		if (!isOwnedByAccount) {
			throw 'This campaign is not owned by your account';
		}

		await campaign.updateOne({
			$set: { name }
		});

		return true;
	}
};

function generateCampaignID() {
	return 'testcampaign';
}
