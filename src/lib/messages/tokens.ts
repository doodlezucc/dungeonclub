import type { IPosition } from '$lib/db/schemas/compounds/position';
import type { IToken } from '$lib/db/schemas/token';
import type { ID, RequestMessage } from './messages';

export interface TokensMessageCategory {
	tokenCreate: RequestMessage<
		{
			tokenDefinition: ID;
			position: IPosition;
		},
		{
			token: IToken;
		}
	>;

	tokenMove: {
		id: ID;
		position: IPosition;
	};
}
