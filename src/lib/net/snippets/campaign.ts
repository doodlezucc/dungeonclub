import type { IPlayer } from '$lib/db/schemas';
import type { BoardPreviewSnippet } from './board';

export interface CampaignCardSnippet {
	id: string;
	name: string;
	createdAt: Date;
	players: PlayerCharacterSnippet[];
}

export interface CampaignSnippet extends CampaignCardSnippet {
	boards: BoardPreviewSnippet[];
}

export interface PlayerCharacterSnippet extends IPlayer {
	name: string;
}
