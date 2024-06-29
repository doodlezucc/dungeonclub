import { publicResponse, type BoardMessageCategory } from '$lib/net';
import { prisma } from '../server';
import type { CategoryHandler } from '../socket';

export const boardHandler: CategoryHandler<BoardMessageCategory> = {
	handleBoardView: async (payload, { dispatcher }) => {
		const campaign = dispatcher.session.campaign;

		return await prisma.board.findFirstOrThrow({
			where: {
				campaignId: campaign.id,
				id: payload.id
			},
			include: {
				tokens: true,
				initiativeOrder: {
					include: {
						entries: true
					}
				}
			}
		});
	},

	handleTokenCreate: async (payload, { dispatcher }) => {
		const board = dispatcher.sessionAsOwner.visibleBoard;

		const token = await prisma.token.create({
			data: {
				boardId: board.id,
				templateId: payload.tokenTemplate,
				...payload.position
			}
		});

		return publicResponse(token);
	},

	handleTokenMove: async (payload) => {
		console.log('move token', payload);

		return {
			forwardedResponse: payload
		};
	}
};
