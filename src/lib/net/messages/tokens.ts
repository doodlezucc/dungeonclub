import type { IToken } from '$lib/db/schemas';
import type { IPosition } from '$lib/net/compounds';
import type { DefineRequestWithPublicResponse, DefineSendAndForward, ID } from './messages';

export interface TokensMessageCategory {
	tokenCreate: DefineRequestWithPublicResponse<
		{
			tokenDefinition: ID;
			position: IPosition;
		},
		{
			token: IToken;
		}
	>;

	tokenMove: DefineSendAndForward<{
		id: ID;
		position: IPosition;
	}>;
}
