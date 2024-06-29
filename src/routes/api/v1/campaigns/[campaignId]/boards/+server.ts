import { authorizedEndpoint } from '$lib/server/rest.js';
import { prisma, server } from '$lib/server/server.js';
import { error, json } from '@sveltejs/kit';

export const POST = ({ params: { campaignId }, request }) =>
	authorizedEndpoint(request, async (accountId) => {
		const campaign = await prisma.campaign.findFirst({
			where: {
				id: campaignId
			}
		});

		if (campaign?.ownerId !== accountId) {
			throw error(403);
		}

		const asset = await server.assetManager.uploadAsset(request);

		const board = await prisma.board.create({
			data: {
				campaignId: campaignId,
				mapImageId: asset.id
			}
		});

		return json(board);
	});
