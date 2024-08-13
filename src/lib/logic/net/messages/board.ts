import type { Position } from '$lib/compounds';
import type { BoardSnippet, TokenSnippet } from '../snippets';
import type {
	DefinePrivateRequest,
	DefineRequestWithPublicResponse,
	DefineSendAndForward,
	UUID
} from './messages';

export type TokenCreationSnippet = Pick<TokenSnippet, 'templateId' | 'x' | 'y'> &
	Partial<Omit<TokenSnippet, 'id'>>;

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

	tokensCreate: DefineRequestWithPublicResponse<
		{
			newTokens: TokenCreationSnippet[];
		},
		{
			boardId: UUID;
			tokens: TokenSnippet[];
		}
	>;

	tokensDelete: DefineSendAndForward<{
		tokenIds: UUID[];
	}>;

	tokensMove: DefineSendAndForward<{
		[id: UUID]: Position;
	}>;
}
