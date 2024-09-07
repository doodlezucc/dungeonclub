import { error, json } from '@sveltejs/kit';
import { authorizedEndpoint } from 'server/rest';
import { prisma, server } from 'server/server.js';

export const GET = ({ params: { campaignId }, request }) =>
	authorizedEndpoint(request, async (accountHash) => {
		const campaign = await prisma.campaign.findUnique({
			where: { id: campaignId }
		});

		if (campaign?.ownerEmail !== accountHash) {
			throw error(403);
		}

		const allAssets = await prisma.asset.findMany({
			where: { campaignId: campaign.id }
		});

		return json({
			items: allAssets
		});
	});

export const POST = ({ params: { campaignId }, request }) =>
	authorizedEndpoint(request, async (accountHash) => {
		const campaign = await prisma.campaign.findUnique({
			where: { id: campaignId }
		});

		if (campaign?.ownerEmail !== accountHash) {
			throw error(403);
		}

		const asset = await server.assetManager.uploadAsset(campaignId, request);

		return json(asset);
	});
