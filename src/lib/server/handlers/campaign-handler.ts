import type { CampaignMessageCategory } from '$lib/net';
import { SelectCampaign } from '../../net/snippets';
import { prisma } from '../server';
import type { CategoryHandler } from '../socket';

export const campaignHandler: CategoryHandler<CampaignMessageCategory> = {
	handleCampaignCreate: async ({ name }, { dispatcher }) => {
		const newCampaign = await prisma.campaign.create({
			data: {
				ownerId: dispatcher.loggedInAccountId,
				name,
				id: generateCampaignID()
			},
			select: SelectCampaign
		});

		dispatcher.enterSession(newCampaign.id, { isGM: true });

		return newCampaign;
	},

	handleCampaignEdit: async ({ id, name }, { dispatcher }) => {
		const campaign = await prisma.campaign.update({
			where: {
				ownerId: dispatcher.loggedInAccountId,
				id: id
			},
			data: {
				name: name
				// TODO: delete removed characters from DB, add new characters
			},
			select: SelectCampaign
		});

		return campaign;
	},

	handleCampaignHost: async ({ id }, { dispatcher }) => {
		const campaign = await prisma.campaign.findFirstOrThrow({
			where: {
				ownerId: dispatcher.loggedInAccountId,
				id: id
			},
			select: SelectCampaign
		});

		dispatcher.enterSession(id, { isGM: true });

		return campaign;
	},

	handleCampaignJoin: async ({ id }, { dispatcher }) => {
		const campaign = await prisma.campaign.findFirstOrThrow({
			where: {
				id: id
			},
			select: SelectCampaign
		});

		dispatcher.enterSession(id, { isGM: false });

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
