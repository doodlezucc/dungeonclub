import { error, json } from '@sveltejs/kit';
import { authorizedEndpoint } from 'server/rest.js';
import { prisma, server } from 'server/server.js';
import { SelectBoard } from 'shared/snippets.js';

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
			},
			select: SelectBoard
		});

		return json(board);
	});
