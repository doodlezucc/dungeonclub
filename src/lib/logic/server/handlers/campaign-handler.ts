import type { CampaignMessageCategory } from 'shared';
import { SelectCampaignCard } from '../../net/snippets';
import { generateUniqueString } from '../generate-string';
import { prisma } from '../server';
import type { CategoryHandler } from '../socket';

export const campaignHandler: CategoryHandler<CampaignMessageCategory> = {
	handleCampaignCreate: async ({ name }, { dispatcher }) => {
		const campaignId = await generateCampaignID();

		await prisma.campaign.create({
			data: {
				ownerId: dispatcher.loggedInAccountId,
				name,
				id: campaignId
			}
		});

		return dispatcher.enterSession(campaignId, { enterAsGM: true });
	},

	handleCampaignEdit: async ({ id, name }, { dispatcher }) => {
		const campaignCard = await prisma.campaign.update({
			where: {
				ownerId: dispatcher.loggedInAccountId,
				id: id
			},
			data: {
				name: name
				// TODO: delete removed characters from DB, add new characters
			},
			select: SelectCampaignCard
		});

		return campaignCard;
	},

	handleCampaignHost: async ({ id }, { dispatcher }) => {
		const dispatcherAccount = await prisma.account.findUniqueOrThrow({
			where: { id: dispatcher.loggedInAccountId },
			select: {
				campaigns: { select: { id: true } }
			}
		});

		const isOwner = dispatcherAccount.campaigns.some((campaign) => campaign.id === id);

		if (!isOwner) {
			throw 'You must be the owner of this campaign to be able to host';
		}

		return await dispatcher.enterSession(id, { enterAsGM: true });
	},

	handleCampaignJoin: async ({ id }, { dispatcher }) => {
		return await dispatcher.enterSession(id, { enterAsGM: false });
	}
};

async function generateCampaignID() {
	return generateUniqueString({
		length: 5,
		doesExist: async (id) => {
			const existingCampaign = await prisma.campaign.findFirst({
				where: { id: id },
				select: null
			});

			return existingCampaign != null;
		}
	});
}
