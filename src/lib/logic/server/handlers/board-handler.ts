import { Limits as LIMITS } from 'server/limits';
import { publicResponse, type BoardMessageCategory } from 'shared';
import { SelectBoard, SelectToken, type TokenSnippet } from '../../net/snippets';
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

	handleTokensCreate: async ({ newTokens }, { dispatcher }) => {
		const sessionCampaignId = dispatcher.sessionAsOwner.campaignId;
		const boardId = dispatcher.sessionConnection.visibleBoardId;

		const {
			campaignId,
			_count: { tokens: currentTokenCount }
		} = await prisma.board.findUniqueOrThrow({
			where: {
				id: boardId
			},
			select: {
				campaignId: true,
				_count: {
					select: {
						tokens: true
					}
				}
			}
		});

		if (sessionCampaignId !== campaignId) {
			throw 'Board is not part of the hosted campaign';
		}

		if (newTokens.length + currentTokenCount > LIMITS.tokensPerBoard) {
			throw 'Resulting token count exceeds maximum tokens per board';
		}

		const createdTokens: TokenSnippet[] = [];

		for (const creationSnippet of newTokens) {
			createdTokens.push(
				await prisma.token.create({
					data: {
						boardId,
						conditions: creationSnippet.conditions,
						// initiativeEntry
						// initiativeModifier
						invisible: creationSnippet.invisible,
						label: creationSnippet.label,
						size: creationSnippet.size,
						templateId: creationSnippet.templateId,
						x: creationSnippet.x,
						y: creationSnippet.y
					},
					select: SelectToken
				})
			);
		}

		return publicResponse({
			boardId,
			tokens: createdTokens
		});
	},

	handleTokensDelete: async (payload, { dispatcher }) => {
		const visibleBoardId = dispatcher.sessionConnectionAsOwner.visibleBoardId;

		const { count } = await prisma.token.deleteMany({
			where: {
				id: { in: payload.tokenIds },
				boardId: visibleBoardId
			}
		});

		const expectedDeleteCount = payload.tokenIds.length;

		if (count !== expectedDeleteCount) {
			console.warn(
				`"tokensDelete" affected ${count} tokens, expected ${expectedDeleteCount} deletions.`,
				'Message:',
				payload
			);
		}

		return {
			forwardedResponse: {
				tokenIds: payload.tokenIds
			}
		};
	},

	handleTokensMove: async (payload, { dispatcher }) => {
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
