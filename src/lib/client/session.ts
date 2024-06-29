import type { BoardSnippet } from '$lib/net/snippets/board';
import type { CampaignSnippet } from '$lib/net/snippets/campaign';

export class Session {
	campaign: CampaignSnippet;

	visibleBoard?: BoardSnippet;

	constructor(campaign: CampaignSnippet) {
		this.campaign = campaign;
	}
}
