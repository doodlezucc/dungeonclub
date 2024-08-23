import { type HistoryStore } from '$lib/packages/undo-redo/history';
import type { ClientSocket } from 'client/communication';
import { Board } from 'client/state';
import type { Position } from 'components/compounds';
import type { GetPayload, TokenSnippet } from 'shared';

export interface Context {
	boardHistory: HistoryStore;
	socket: ClientSocket;
}

export interface CreateTokenOptions {
	position: Position;
	tokenTemplateId: string | null;
	onServerSideCreation: (instantiatedToken: TokenSnippet) => void;
}

export function createNewToken(options: CreateTokenOptions, context: Context) {
	const { boardHistory, socket } = context;
	const { position, tokenTemplateId } = options;

	let instantiatedToken: TokenSnippet | null = null;

	boardHistory.registerUndoable('Add token to board', async () => {
		const isInitialCreation = instantiatedToken === null;

		if (isInitialCreation) {
			const response = await socket.request('tokenCreate', {
				x: position.x,
				y: position.y,
				templateId: tokenTemplateId
			});
			Board.instance.handleTokenCreate(response);

			instantiatedToken = response.token;
			options.onServerSideCreation(instantiatedToken);
		} else {
			socket.send('tokensRestore', {
				tokenIds: [instantiatedToken!.id]
			});
		}

		return {
			undo: () => {
				const payload: GetPayload<'tokensDelete'> = {
					tokenIds: [instantiatedToken!.id]
				};

				socket.send('tokensDelete', payload);
				Board.instance.handleTokensDelete(payload);
			}
		};
	});
}

export function deleteTokens(tokens: TokenSnippet[], context: Context) {
	const { boardHistory, socket } = context;

	const actionName = tokens.length === 1 ? 'Remove token from board' : 'Remove tokens from board';
	const tokenIds = tokens.map((token) => token.id);

	boardHistory.registerUndoable(actionName, async () => {
		socket.send('tokensDelete', {
			tokenIds: tokenIds
		});

		Board.instance.handleTokensDelete({ tokenIds: tokenIds });

		return {
			undo: () => {
				socket.send('tokensRestore', {
					tokenIds: tokenIds
				});
			}
		};
	});
}
