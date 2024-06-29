import type { IPosition } from '../compounds';
import type { BoardSnippet, TokenSnippet } from '../snippets/board';
import type {
	DefinePrivateRequest,
	DefineRequestWithPublicResponse,
	DefineSendAndForward,
	UUID
} from './messages';

export interface BoardMessageCategory {
	boardCreate: DefinePrivateRequest<
		{
			name?: string;
		},
		BoardSnippet
	>;

	boardView: DefinePrivateRequest<
		{
			uuid: UUID;
		},
		BoardSnippet
	>;

	tokenCreate: DefineRequestWithPublicResponse<
		{
			tokenDefinition: UUID;
			position: IPosition;
		},
		TokenSnippet
	>;

	tokenMove: DefineSendAndForward<{
		id: UUID;
		position: IPosition;
	}>;
}
