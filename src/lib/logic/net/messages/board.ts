import type { Position } from '$lib/compounds';
import type { BoardSnippet, TokenSnippet } from '../snippets';
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
		{
			templateId: string | null;
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

	tokensMove: DefineSendAndForward<{
		[id: UUID]: Position;
	}>;
}
