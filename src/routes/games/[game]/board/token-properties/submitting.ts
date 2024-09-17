import { getSocket } from 'client/communication';
import type {
	GetPayload,
	TokenProperties,
	TokenPropertiesOrNull,
	TokenSnippet,
	TokenTemplateSnippet
} from 'shared';
import { extractOverridableProperties } from 'shared/token-materializing';

export function getRawCommonTokenTemplateProperties(
	singleTokenTemplateId: string | null,
	allTemplates: TokenTemplateSnippet[]
) {
	if (!singleTokenTemplateId) return null;

	const properties = extractOverridableProperties(
		allTemplates.find((template) => template.id === singleTokenTemplateId)!
	);

	// Templates don't have "null" values, we can safely cast.
	return properties as TokenProperties;
}

export function getRawSelectedTokenProperties(
	selectedTokenIds: string[],
	allTokens: TokenSnippet[]
) {
	const result: Record<string, TokenPropertiesOrNull> = {};
	const updatedSelectedTokens = selectedTokenIds.map(
		(id) => allTokens.find((token) => token.id === id)!
	);

	for (const token of updatedSelectedTokens) {
		result[token.id] = extractOverridableProperties(token);
	}

	return result;
}

export function submitTokenPropertiesToServer(payload: GetPayload<'tokensEdit'>) {
	getSocket().send('tokensEdit', payload);
}
