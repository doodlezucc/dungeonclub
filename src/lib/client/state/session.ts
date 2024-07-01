import type { BoardSnippet } from '$lib/net/snippets/board';
import type { CampaignSnippet } from '$lib/net/snippets/campaign';
import { writable } from 'svelte/store';

export const session = writable<Session | null>(null);

export class Session {
	campaign: CampaignSnippet;

	visibleBoard?: BoardSnippet;

	constructor(campaign: CampaignSnippet) {
		this.campaign = campaign;
	}
}
