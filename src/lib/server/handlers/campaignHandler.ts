import { Campaign } from '$lib/db/schemas';
import type { CampaignMessageCategory } from '$lib/net';
import { Session } from '../connection';
import type { CategoryHandler } from '../socket';

export const campaignHandler: CategoryHandler<CampaignMessageCategory> = {
	handleCampaignCreate: async ({ name }, { dispatcher }) => {
		const account = dispatcher.loggedInAccount;

		const newCampaign = await Campaign.create({
			name,
			id: generateCampaignID()
		});

		await account.updateOne({
			$push: { campaigns: newCampaign._id }
		});

		return newCampaign;
	},

	handleCampaignEdit: async ({ id, name, players }, { dispatcher }) => {
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

		// TODO: delete removed characters from DB, add new characters

		await campaign.updateOne({
			$set: { name }
		});

		return {
			id,
			name,
			players,
			createdAt: campaign.createdAt
		};
	},

	handleCampaignHost: async ({ id }, { dispatcher }) => {
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

		dispatcher.onEnterSession(new Session(campaign, true));

		return {
			id,
			name: campaign.name,
			players: [],
			boards: campaign.boards.map((board) => ({
				uuid: board.id,
				name: board.name
			})),
			createdAt: campaign.createdAt
		};
	},

	handleCampaignJoin: async ({ id }, { dispatcher }) => {
		const campaign = await Campaign.findOne({ id });

		if (!campaign) {
			throw 'Campaign not found';
		}

		dispatcher.onEnterSession(new Session(campaign, false));

		return {
			id,
			name: campaign.name,
			players: [],
			boards: campaign.boards.map((board) => ({
				uuid: board.id,
				name: board.name
			})),
			createdAt: campaign.createdAt
		};
	}
};

function generateCampaignID() {
	const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	const lowercase = 'abcdefghijklmnopqrstuvwxyz';
	const digits = '0123456789';

	const pool = [uppercase, lowercase, digits].join('');

	function randomCharacter() {
		return pool[Math.floor(Math.random() * pool.length)];
	}

	let result = '';

	for (let i = 0; i < 5; i++) {
		result += randomCharacter();
	}

	return result;
}
