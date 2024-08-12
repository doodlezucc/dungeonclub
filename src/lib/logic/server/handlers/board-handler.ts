import { publicResponse, type BoardMessageCategory } from 'shared';
import { SelectBoard, SelectToken } from '../../net/snippets';
import { prisma } from '../server';
import type { CategoryHandler } from '../socket';

export const boardHandler: CategoryHandler<BoardMessageCategory> = {
	handleBoardEdit: async ({ id: boardId }, { dispatcher }) => {
		const campaignId = dispatcher.sessionAsOwner.campaignId;

		const boardSnippet = await prisma.board.findFirstOrThrow({
			where: {
				campaignId: campaignId,
				id: boardId
			},
			select: SelectBoard
		});

		dispatcher.sessionConnection.visibleBoardIdOrNull = boardId;

		return boardSnippet;
	},

	handleBoardPlay: async ({ id: boardId }, { dispatcher }) => {
		const session = dispatcher.sessionAsOwner;
		const campaignId = session.campaignId;

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

		for (const user of session.users) {
			user.sessionConnection.visibleBoardIdOrNull = boardId;
		}

		return publicResponse(boardSnippet);
	},

	handleTokenCreate: async (payload, { dispatcher }) => {
		const sessionCampaignId = dispatcher.sessionAsOwner.campaignId;
		const boardId = dispatcher.sessionConnection.visibleBoardId;

		const { campaignId } = await prisma.board.findUniqueOrThrow({
			where: {
				id: boardId
			},
			select: { campaignId: true }
		});

		if (sessionCampaignId !== campaignId) {
			throw 'Board is not part of the hosted campaign';
		}

		const token = await prisma.token.create({
			data: {
				boardId,
				templateId: payload.tokenTemplate,
				...payload.position
			},
			select: SelectToken
		});

		return publicResponse({
			token,
			boardId
		});
	},

	handleTokenDelete: async ({ tokenId }, { dispatcher }) => {
		const sessionCampaignId = dispatcher.sessionAsOwner.campaignId;

		const token = await prisma.token.findUniqueOrThrow({
			where: { id: tokenId },
			select: {
				board: {
					select: {
						campaignId: true
					}
				}
			}
		});

		if (sessionCampaignId !== token.board.campaignId) {
			throw 'Token is not part of the hosted campaign';
		}

		await prisma.token.delete({
			where: { id: tokenId }
		});

		return {
			forwardedResponse: {
				tokenId
			}
		};
	},

	handleTokenMove: async (payload, { dispatcher }) => {
		const boardId = dispatcher.sessionConnection.visibleBoardId;

		for (const tokenId in payload) {
			const position = payload[tokenId];

			await prisma.token.update({
				where: { boardId, id: tokenId },
				data: {
					x: position.x,
					y: position.y
				},
				select: null
			});
		}

		return {
			forwardedResponse: payload
		};
	}
};
