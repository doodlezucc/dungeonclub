import { RestConnection } from '$lib/client/communication';
import { campaignState } from '$lib/client/state';
import type { TokenTemplateSnippet } from '$lib/net';
import { get } from 'svelte/store';

interface CreateTokenTemplateOptions {
	avatarImageFile: File;
}

export async function restPostTokenTemplate(options: CreateTokenTemplateOptions) {
	const { avatarImageFile } = options;

	const activeCampaignId = get(campaignState)!.id;

	return (await RestConnection.instance.postFile(
		`/campaigns/${activeCampaignId}/token-templates`,
		avatarImageFile
	)) as TokenTemplateSnippet;
}
