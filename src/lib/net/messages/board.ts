import type { Point } from 'packages/math';
import type { BoardSnippet, TokenProperties, TokenSnippet } from '../snippets';
import type {
	DefinePrivateRequest,
	DefineRequestWithPublicResponse,
	DefineSendAndForward,
	UUID
} from './messages';

export interface BoardMessageCategory {
	boardEdit: DefinePrivateRequest<
		{
			id: UUID;
		},
		BoardSnippet
	>;

	boardPlay: DefineRequestWithPublicResponse<
		{
			id: UUID;
		},
		BoardSnippet
	>;

	tokenCreate: DefineRequestWithPublicResponse<
		TokenProperties & {
			x: number;
			y: number;
		},
		{
			boardId: UUID;
			token: TokenSnippet;
		}
	>;

	tokensDelete: DefineSendAndForward<{
		tokenIds: UUID[];
	}>;

	tokensRestore: DefinePrivateRequest<
		{
			tokenIds: UUID[];
		},
		void
	>;

	tokensEdit: DefineSendAndForward<{
		editedTokens: {
			[id: UUID]: TokenProperties;
		};
	}>;

	tokensMove: DefineSendAndForward<{
		[id: UUID]: Point;
	}>;
}
