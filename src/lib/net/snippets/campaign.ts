import type { UUID } from '../messages';
import type { BoardPreviewSnippet } from './board';

export interface CampaignCardSnippet {
	id: string;
	name: string;
	createdAt: Date;
	playerCharacters: PlayerCharacterSnippet[];
}

export interface CampaignSnippet extends CampaignCardSnippet {
	boards: BoardPreviewSnippet[];
}

export interface PlayerCharacterSnippet {
	tokenTemplateId: UUID;
}
