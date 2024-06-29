import type { UUID } from '../messages';

export interface BoardPreviewSnippet {
	id: UUID;
	name: string;
}

export interface BoardSnippet extends BoardPreviewSnippet {
	tokens: TokenSnippet[];
	gridCellsPerRow: number;
}

export interface TokenSnippet {
	id: UUID;
	templateId: UUID;
}
