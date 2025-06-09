import type { CampaignSnippet, GetPayload } from '$lib/net';
import { derived, readable } from 'svelte/store';
import { getSocket } from '../communication/socket';
import { Board } from './board';
import { WithState } from './with-state';

export class Campaign extends WithState<CampaignSnippet> {
	static readonly instance = new Campaign();

	async join(options: GetPayload<'campaignJoin'>) {
		this.onEnter(await getSocket().request('campaignJoin', options));
	}

	onEnter(snippet: CampaignSnippet) {
		this.set(snippet);

		if (snippet.selectedBoard) {
			Board.instance.load(snippet.selectedBoard);
		}
	}

	readonly tokenPresets = this.derived(
		(campaign) => campaign.presets,
		(campaign, presets) => ({
			...campaign,
			presets: presets
		})
	);

	readonly assets = this.derived(
		(campaign) => campaign.assets,
		(campaign, assets) => ({
			...campaign,
			assets: assets
		})
	);

	assetById(id: string) {
		return derived(this.assets, (assets) => {
			return assets.find((asset) => asset.id === id)!;
		});
	}

	assetByNullableId(id: string | null) {
		if (id) {
			return this.assetById(id);
		} else {
			return readable(null);
		}
	}

	handleAssetCreate(payload: GetPayload<'assetCreate'>) {
		this.assets.update((assets) => {
			return [...assets, payload.asset];
		});
	}

	handleTokenPresetCreate(payload: GetPayload<'tokenPresetCreate'>) {
		this.tokenPresets.update((presets) => {
			return [...presets, payload.tokenPreset];
		});
	}
}

export class Session {
	static readonly instance = new Session();
}

export const campaignState = Campaign.instance.state;
