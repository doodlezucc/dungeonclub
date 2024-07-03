import { error, json } from '@sveltejs/kit';
import { authorizedEndpoint } from 'server/rest.js';
import { prisma } from 'server/server.js';

export const GET = ({ request, params }) =>
	authorizedEndpoint(request, async (accountId) => {
		const board = await prisma.board.findFirstOrThrow({
			where: {
				id: params.boardId,
				campaignId: params.campaignId
			},
			include: {
				campaign: { select: { ownerId: true } }
			}
		});

		if (board.campaign.ownerId !== accountId) {
			throw error(403);
		}

		return json(board);
	});
