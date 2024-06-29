import type { Position } from '../../compounds';
import type { BoardSnippet, TokenSnippet } from '../snippets/board';
import type {
	DefinePrivateRequest,
	DefineRequestWithPublicResponse,
	DefineSendAndForward,
	UUID
} from './messages';

export interface BoardMessageCategory {
	boardView: DefinePrivateRequest<
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
		TokenSnippet
	>;

	tokenMove: DefineSendAndForward<{
		id: UUID;
		position: Position;
	}>;
}
