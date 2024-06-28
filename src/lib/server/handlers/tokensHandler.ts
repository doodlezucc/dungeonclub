import { CustomTokenDefinition, Token } from '$lib/db/schemas';
import { publicResponse, type TokensMessageCategory } from '$lib/net';
import type { CategoryHandler } from '../socket';

export const tokensHandler: CategoryHandler<TokensMessageCategory> = {
	handleTokenCreate: async (payload, { dispatcher }) => {
		const scene = dispatcher.sessionAsOwner.visibleScene;

		const token = await Token.create({
			definition: await CustomTokenDefinition.findById(payload.tokenDefinition),
			position: payload.position
		});

		await scene.updateOne({
			$push: {
				tokens: token
			}
		});

		return publicResponse({
			token
		});
	},

	handleTokenMove: async (payload) => {
		console.log('move token', payload);

		return {
			forwardedResponse: payload
		};
	}
};
