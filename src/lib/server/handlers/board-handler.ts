import { publicResponse, type BoardMessageCategory } from '$lib/net';
import { SelectBoard, SelectToken } from '../../net/snippets';
import { prisma } from '../server';
import type { CategoryHandler } from '../socket';

export const boardHandler: CategoryHandler<BoardMessageCategory> = {
	handleBoardView: async ({ id: boardId }, { dispatcher }) => {
		const campaignId = dispatcher.session.campaignId;

		return await prisma.board.findFirstOrThrow({
			where: {
				campaignId: campaignId,
				id: boardId
			},
			select: SelectBoard
		});
	},

	handleTokenCreate: async (payload, { dispatcher }) => {
		const board = dispatcher.sessionAsOwner.visibleBoard;

		const token = await prisma.token.create({
			data: {
				boardId: board.id,
				templateId: payload.tokenTemplate,
				...payload.position
			},
			select: SelectToken
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
