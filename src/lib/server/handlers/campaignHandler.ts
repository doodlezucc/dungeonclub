import type { CampaignMessageCategory } from '$lib/net';
import { Session } from '../connection';
import { prisma } from '../server';
import type { CategoryHandler } from '../socket';

export const campaignHandler: CategoryHandler<CampaignMessageCategory> = {
	handleCampaignCreate: async ({ name }, { dispatcher }) => {
		const account = dispatcher.loggedInAccount;

		const newCampaign = await prisma.campaign.create({
			data: {
				ownerId: account.id,
				name,
				id: generateCampaignID()
			},
			include: {
				boards: true,
				playerCharacters: true,
				templates: true
			}
		});

		return newCampaign;
	},

	handleCampaignEdit: async ({ id, name }, { dispatcher }) => {
		const campaign = await prisma.campaign.update({
			where: {
				ownerId: dispatcher.loggedInAccount.id,
				id: id
			},
			data: {
				name: name
				// TODO: delete removed characters from DB, add new characters
			},
			include: {
				playerCharacters: true
			}
		});

		return campaign;
	},

	handleCampaignHost: async ({ id }, { dispatcher }) => {
		const campaign = await prisma.campaign.findFirstOrThrow({
			where: {
				ownerId: dispatcher.loggedInAccount.id,
				id: id
			},
			include: {
				playerCharacters: true,
				boards: true,
				templates: true
			}
		});

		dispatcher.onEnterSession(new Session(campaign, true));

		return campaign;
	},

	handleCampaignJoin: async ({ id }, { dispatcher }) => {
		const campaign = await prisma.campaign.findFirstOrThrow({
			where: {
				id: id
			},
			include: {
				playerCharacters: true,
				boards: true,
				templates: true
			}
		});

		dispatcher.onEnterSession(new Session(campaign, true));

		return campaign;
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
