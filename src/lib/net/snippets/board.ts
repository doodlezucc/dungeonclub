import type { UUID } from '../messages';

export interface BoardPreviewSnippet {
	uuid: UUID;
	name: string;
}

export interface BoardSnippet extends BoardPreviewSnippet {
	tokens: TokenSnippet[];
}

export interface TokenSnippet {
	uuid: UUID;
	definition: UUID;
}
