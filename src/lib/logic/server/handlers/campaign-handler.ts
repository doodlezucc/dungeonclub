import type { CampaignMessageCategory } from 'shared';
import { SelectCampaignCard } from '../../net/snippets';
import { prisma } from '../server';
import type { CategoryHandler } from '../socket';
import { generateUniqueString } from '../util/generate-string';

export const campaignHandler: CategoryHandler<CampaignMessageCategory> = {
	handleCampaignCreate: async ({ name }, { dispatcher }) => {
		const campaignId = await generateCampaignID();

		await prisma.campaign.create({
			data: {
				ownerEmail: dispatcher.loggedInAccountHash,
				name,
				id: campaignId
			}
		});

		return dispatcher.enterSession(campaignId);
	},

	handleCampaignEdit: async ({ id, name }, { dispatcher }) => {
		const campaignCard = await prisma.campaign.update({
			where: {
				ownerEmail: dispatcher.loggedInAccountHash,
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
			where: { emailHash: dispatcher.loggedInAccountHash },
			select: {
				campaigns: { select: { id: true } }
			}
		});

		const isOwner = dispatcherAccount.campaigns.some((campaign) => campaign.id === id);

		if (!isOwner) {
			throw 'You must be the owner of this campaign to be able to host';
		}

		return await dispatcher.enterSession(id);
	},

	handleCampaignJoin: async ({ id }, { dispatcher }) => {
		return await dispatcher.enterSession(id);
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
