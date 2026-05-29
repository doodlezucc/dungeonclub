import { RestConnection } from '$lib/client/communication';
import { campaignState } from '$lib/client/state';
import type { TokenPresetSnippet } from '$lib/net';
import { get } from 'svelte/store';

interface CreateTokenPresetOptions {
	avatarImageFile: File;
}

export async function restPostTokenPreset(options: CreateTokenPresetOptions) {
	const { avatarImageFile } = options;

	const activeCampaignId = get(campaignState)!.id;

	return (await RestConnection.instance.postFile(
		`/campaigns/${activeCampaignId}/token-presets`,
		avatarImageFile
	)) as TokenPresetSnippet;
}
