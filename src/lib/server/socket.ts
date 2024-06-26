import { Token } from '$lib/db/schemas/token';
import { CustomTokenDefinition } from '$lib/db/schemas/token-definition';
import { MessageHandler, type CategoryHandlers } from '$lib/messages/handling';
import type { TokensMessageCategory } from '$lib/messages/tokens';
import { Connection } from './connection';

export interface HandlerOptions {
	dispatcher: Connection;
}

export class ServerMessageHandler extends MessageHandler<HandlerOptions> {
	tokens: CategoryHandlers<TokensMessageCategory, HandlerOptions> = {
		handleTokenCreate: async (payload, { dispatcher }) => {
			const token = await Token.create({
				definition: await CustomTokenDefinition.findById(payload.tokenDefinition),
				position: payload.position
			});

			await dispatcher.session?.campaign?.updateOne({
				$push: {
					'scenes.0.tokens': token
				}
			});

			return {
				token
			};
		},

		handleTokenMove: async (payload) => {
			console.log('move token', payload);
		}
	};
}

export const serverMessageHandler = new ServerMessageHandler();
