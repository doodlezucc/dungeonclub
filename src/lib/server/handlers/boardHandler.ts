import { Board, CustomTokenDefinition, Token, type Hydrated, type IToken } from '$lib/db/schemas';
import { publicResponse, type BoardMessageCategory } from '$lib/net';
import type { TokenSnippet } from '$lib/net/snippets/board';
import type { CategoryHandler } from '../socket';

export const boardHandler: CategoryHandler<BoardMessageCategory> = {
	handleBoardCreate: async (payload, { dispatcher }) => {
		const campaign = dispatcher.sessionAsOwner.campaign;

		const board = new Board({
			name: payload.name ?? 'Untitled board',
			background: 'sample-background.png'
		});

		await campaign.updateOne({
			$push: { boards: board }
		});

		return {
			uuid: board.id,
			name: board.name,
			tokens: []
		};
	},

	handleBoardView: async (payload, { dispatcher }) => {
		const campaign = dispatcher.session.campaign;

		const board = campaign.boards.find((board) => board.id === payload.uuid);

		if (!board) throw 'Board not found';

		return {
			uuid: board.id,
			name: board.name,
			tokens: board.tokens.map((token) => ({
				uuid: (token as Hydrated<IToken>).id,
				definition: `${token.definition}`
			}))
		};
	},

	handleTokenCreate: async (payload, { dispatcher }) => {
		const board = dispatcher.sessionAsOwner.visibleBoard;

		const token = await Token.create({
			definition: await CustomTokenDefinition.findById(payload.tokenDefinition),
			position: payload.position
		});

		await board.updateOne({
			$push: {
				tokens: token
			}
		});

		return publicResponse(<TokenSnippet>{
			uuid: token.id,
			definition: `${token.definition}`
		});
	},

	handleTokenMove: async (payload) => {
		console.log('move token', payload);

		return {
			forwardedResponse: payload
		};
	}
};
