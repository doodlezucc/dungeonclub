import type { CampaignSnippet } from '$lib/net';
import { writable } from 'svelte/store';

export const session = writable<Session | null>(null);

export class Session {
	campaign: CampaignSnippet;

	constructor(campaign: CampaignSnippet) {
		this.campaign = campaign;
	}
}
