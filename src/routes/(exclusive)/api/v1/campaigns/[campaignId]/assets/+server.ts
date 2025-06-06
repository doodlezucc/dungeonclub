import { campaignEndpoint } from '$lib/server/rest.js';
import { prisma, server } from '$lib/server/server.js';
import { json } from '@sveltejs/kit';

export const GET = ({ params: { campaignId }, request }) =>
	campaignEndpoint(request, campaignId, async () => {
		const allAssets = await prisma.asset.findMany({
			where: { campaignId: campaignId }
		});

		return json({
			items: allAssets
		});
	});

export const POST = ({ params: { campaignId }, request }) =>
	campaignEndpoint(request, campaignId, async () => {
		const asset = await server.assetManager.uploadAsset(campaignId, request);

		return json(asset);
	});
