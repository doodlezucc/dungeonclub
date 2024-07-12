import { error, json } from '@sveltejs/kit';
import { authorizedEndpoint } from 'server/rest.js';
import { prisma, server } from 'server/server.js';
import { SelectBoard } from 'shared/snippets.js';

export const POST = ({ params: { campaignId }, request }) =>
	authorizedEndpoint(request, async (accountHash) => {
		const campaign = await prisma.campaign.findFirst({
			where: {
				id: campaignId
			}
		});

		if (campaign?.ownerEmail !== accountHash) {
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

		if (campaign.selectedBoardId === null) {
			await prisma.campaign.update({
				where: { id: campaign.id },
				data: { selectedBoardId: board.id }
			});
		}

		return json(board);
	});
