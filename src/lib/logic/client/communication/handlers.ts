import { Board } from 'client/state';
import {
	MessageHandler,
	type AccountMessageCategory,
	type BoardMessageCategory,
	type CampaignMessageCategory,
	type CategoryHandlers,
	type ClientHandledMessages
} from 'shared';

type Options = unknown;

export class ClientRequestHandler extends MessageHandler<ClientHandledMessages, Options> {
	account: CategoryHandlers<AccountMessageCategory, ClientHandledMessages, Options> = {};

	board: CategoryHandlers<BoardMessageCategory, ClientHandledMessages, Options> = {
		onBoardPlay: (boardSnippet) => {
			Board.instance.load(boardSnippet);
		},

		onTokenCreate: (payload) => {
			console.log('onTokenCreate', payload);
		},

		onTokenMove: (payload) => {
			console.log('onTokenMove', payload);
		}
	};

	campaign: CategoryHandlers<CampaignMessageCategory, ClientHandledMessages, Options> = {};
}
