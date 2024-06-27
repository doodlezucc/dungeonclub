import {
	MessageHandler,
	type AccountMessageCategory,
	type CategoryHandlers,
	type ClientHandledMessages,
	type TokensMessageCategory
} from '$lib/net';

type Options = unknown;

export class ClientRequestHandler extends MessageHandler<ClientHandledMessages, Options> {
	account: CategoryHandlers<AccountMessageCategory, ClientHandledMessages, Options> = {};

	tokens: CategoryHandlers<TokensMessageCategory, ClientHandledMessages, Options> = {
		onTokenCreate: (payload) => {
			console.log('onTokenCreate', payload);
		},

		onTokenMove: (payload) => {
			console.log('onTokenMove', payload);
		}
	};
}
