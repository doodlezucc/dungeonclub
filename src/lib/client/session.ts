import type { IBoard } from '$lib/db/schemas';
import type { CampaignSnippet } from '$lib/net/snippets/campaign';

export class Session {
	campaign: CampaignSnippet;

	visibleBoard?: IBoard;

	constructor(campaign: CampaignSnippet) {
		this.campaign = campaign;
	}
}
