import { Board } from 'client/state';
import {
	MessageHandler,
	type AccountMessageCategory,
	type BoardMessageCategory,
	type CampaignMessageCategory,
	type CategoryHandlers,
	type ClientHandledMessages
} from 'shared';

type Options = {};

export class ClientRequestHandler extends MessageHandler<ClientHandledMessages, Options> {
	account: CategoryHandlers<AccountMessageCategory, ClientHandledMessages, Options> = {};

	board: CategoryHandlers<BoardMessageCategory, ClientHandledMessages, Options> = {
		onBoardPlay: (boardSnippet) => {
			Board.instance.load(boardSnippet);
		},

		onTokenCreate: (payload) => Board.instance.handleTokenCreate(payload),
		onTokenDelete: (payload) => Board.instance.handleTokenDelete(payload),
		onTokenMove: (payload) => Board.instance.handleTokenMove(payload)
	};

	campaign: CategoryHandlers<CampaignMessageCategory, ClientHandledMessages, Options> = {};
}
