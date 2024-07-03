import type { CampaignSnippet, GetPayload } from '$lib/net';
import { derived } from 'svelte/store';
import { getSocket } from '../communication';
import { Board } from './board';
import { WithState } from './with-state';

export class Campaign extends WithState<CampaignSnippet> {
	async join(options: GetPayload<'campaignJoin'>) {
		this.onEnter(await getSocket().request('campaignJoin', options));
	}

	onEnter(snippet: CampaignSnippet) {
		this.set(snippet);

		if (snippet.selectedBoard) {
			Board.instance.load(snippet.selectedBoard);
		}
	}
}

export class Session {
	static readonly instance = new Session();
	static readonly state = this.instance.state;

	readonly campaign = new Campaign();
	readonly state = derived([this.campaign.state], ([campaign]) => ({
		campaign
	}));
}

export const sessionState = Session.state;
