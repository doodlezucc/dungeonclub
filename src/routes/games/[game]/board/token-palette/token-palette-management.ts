import { RestConnection } from '$lib/client/communication';
import { Board, campaignState } from '$lib/client/state';
import type { TokenTemplateSnippet } from '$lib/net';
import {
	extractPropertiesFromTemplate,
	getInheritedPropertiesOfToken
} from '$lib/net/token-materializing';
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

export function detachTemplateFromVisibleTokens(deletedTemplate: TokenTemplateSnippet) {
	Board.instance.put((board) => ({
		...board,
		tokens: board.tokens.map((token) => {
			if (token.templateId !== deletedTemplate.id) return token;

			const newlyAppliedProperties = extractPropertiesFromTemplate(
				deletedTemplate,
				getInheritedPropertiesOfToken(token)
			);

			return {
				...token,
				...newlyAppliedProperties
			};
		})
	}));
}
