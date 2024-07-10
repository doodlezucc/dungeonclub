import { publicResponse, type BoardMessageCategory } from 'shared';
import { SelectBoard, SelectToken } from '../../net/snippets';
import { prisma } from '../server';
import type { CategoryHandler } from '../socket';

export const boardHandler: CategoryHandler<BoardMessageCategory> = {
	handleBoardEdit: async ({ id: boardId }, { dispatcher }) => {
		const campaignId = dispatcher.sessionAsOwner.campaignId;

		return await prisma.board.findFirstOrThrow({
			where: {
				campaignId: campaignId,
				id: boardId
			},
			select: SelectBoard
		});
	},

	handleBoardPlay: async ({ id: boardId }, { dispatcher }) => {
		const campaignId = dispatcher.sessionAsOwner.campaignId;

		const boardSnippet = await prisma.board.findFirstOrThrow({
			where: {
				campaignId: campaignId,
				id: boardId
			},
			select: SelectBoard
		});

		await prisma.campaign.update({
			where: { id: campaignId },
			data: {
				selectedBoardId: boardId
			}
		});

		return publicResponse(boardSnippet);
	},

	handleTokenCreate: async (payload, { dispatcher }) => {
		const boardId = dispatcher.sessionAsOwner && dispatcher.activeBoardId;

		const token = await prisma.token.create({
			data: {
				boardId,
				templateId: payload.tokenTemplate,
				...payload.position
			},
			select: SelectToken
		});

		return publicResponse(token);
	},

	handleTokenMove: async (payload, { dispatcher }) => {
		const boardId = dispatcher.sessionAsOwner && dispatcher.activeBoardId;

		await prisma.token.update({
			where: { boardId, id: payload.id },
			data: {
				x: payload.position.x,
				y: payload.position.y
			},
			select: null
		});

		return {
			forwardedResponse: payload
		};
	}
};
