import type { IPosition } from '$lib/db/schemas/compounds/position';
import type { IToken } from '$lib/db/schemas/token';
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
