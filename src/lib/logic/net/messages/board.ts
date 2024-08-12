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
			tokenTemplate: UUID;
			position: Position;
		},
		{
			boardId: UUID;
			token: TokenSnippet;
		}
	>;

	tokenDelete: DefineSendAndForward<{
		tokenId: UUID;
	}>;

	tokenMove: DefineSendAndForward<{
		[id: UUID]: Position;
	}>;
}
