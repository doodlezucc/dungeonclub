import type { CampaignMessageCategory } from '$lib/net';
import { SelectCampaignCard, SelectTokenPreset, SelectTokenProperties } from '../../net/snippets';
import { prisma, server } from '../server';
import type { CategoryHandler } from '../socket';
import { generateUniqueString } from '../util/generate-string';

export const campaignHandler: CategoryHandler<CampaignMessageCategory> = {
	handleCampaignCreate: async ({ name }, { dispatcher }) => {
		const campaignId = await generateCampaignID();

		await prisma.account.update({
			where: { emailHash: dispatcher.loggedInAccountHash },
			data: {
				campaigns: {
					create: {
						name,
						id: campaignId
					}
				},
				campaignIdsOrdered: {
					push: campaignId
				}
			}
		});

		return dispatcher.enterSession(campaignId);
	},

	handleCampaignDelete: async ({ id }, { dispatcher }) => {
		const { campaigns, campaignIdsOrdered } = await prisma.account.findUniqueOrThrow({
			where: { emailHash: dispatcher.loggedInAccountHash },
			select: {
				campaigns: { select: { id: true } },
				campaignIdsOrdered: true
			}
		});

		const isOwner = campaigns.some((campaign) => campaign.id === id);

		if (!isOwner) {
			throw 'You must be the owner of this campaign to be able to delete it';
		}

		const selectedAssets = await prisma.campaign.findUniqueOrThrow({
			where: { id: id },
			select: {
				boards: {
					select: {
						mapImage: true
					}
				},
				presets: {
					select: {
						avatar: true
					}
				}
			}
		});

		const allAssets = [
			...selectedAssets.boards.map((board) => board.mapImage),
			...selectedAssets.presets.map((preset) => preset.avatar).filter((asset) => asset != null)
		];

		await server.assetManager.disposeAssetsInBatch(allAssets);

		await prisma.account.update({
			where: { emailHash: dispatcher.loggedInAccountHash },
			data: {
				campaigns: {
					delete: { id: id }
				},
				campaignIdsOrdered: campaignIdsOrdered.filter((ownedId) => ownedId !== id)
			}
		});
	},

	handleCampaignReorder: async ({ campaignIds }, { dispatcher }) => {
		await prisma.account.updateArrayOrder({
			where: { emailHash: dispatcher.accountHash },
			arrayName: 'campaignIdsOrdered',
			updateTo: campaignIds
		});
	},

	handleCampaignEdit: async ({ id, name }, { dispatcher }) => {
		const campaignCard = await prisma.campaign.update({
			where: {
				ownerEmail: dispatcher.loggedInAccountHash,
				id: id
			},
			data: {
				name: name
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
	},

	handleTokenPresetDelete: async ({ tokenPresetId }, { dispatcher }) => {
		const session = dispatcher.sessionAsOwner;
		const campaignId = session.campaignId;

		const tokenPreset = await prisma.tokenPreset.findUnique({
			where: { id: tokenPresetId },
			select: {
				...SelectTokenPreset,
				...SelectTokenProperties,
				campaignId: true
			}
		});

		if (tokenPreset?.campaignId !== campaignId) {
			throw 'Token preset is not part of the hosted campaign';
		}

		session.garbage.tokenPresets.markForDeletion(tokenPresetId, {
			tokenPreset: tokenPreset
		});
	},

	handleTokenPresetRestore: async ({ tokenPresetId }, { dispatcher }) => {
		const session = dispatcher.sessionAsOwner;

		session.garbage.tokenPresets.restore(tokenPresetId);
	},

	// FIXME: Only here because [Server -> Client] broadcasts aren't yet possible to define under net/messages/*.
	handleAssetCreate: async (payload) => {
		return { forwardedResponse: payload };
	},

	// FIXME: Only here because [Server -> Client] broadcasts aren't yet possible to define under net/messages/*.
	handleTokenPresetCreate: async (payload) => {
		return { forwardedResponse: payload };
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
