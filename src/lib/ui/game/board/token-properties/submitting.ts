import { getSocket } from '$lib/client/communication';
import type { GetPayload, TokenProperties, TokenSnippet } from '$lib/net';
import isEqual from 'lodash/isEqual';

export function getRawSelectedTokenProperties(
	selectedTokenIds: string[],
	allTokens: TokenSnippet[]
) {
	const result: Record<string, TokenProperties> = {};
	const updatedSelectedTokens = selectedTokenIds.map(
		(id) => allTokens.find((token) => token.id === id)!
	);

	for (const token of updatedSelectedTokens) {
		result[token.id] = token;
	}

	return result;
}

export function buildWebSocketPayload(
	selectedTokenIds: string[],
	allTokens: TokenSnippet[]
): GetPayload<'tokensEdit'> {
	const tokenProperties = getRawSelectedTokenProperties(selectedTokenIds, allTokens);

	return {
		editedTokens: tokenProperties
	};
}

export function arePayloadsEqual(
	previousPayload: GetPayload<'tokensEdit'>,
	newPayload: GetPayload<'tokensEdit'>
) {
	return isEqual(previousPayload, newPayload);
}

export function submitTokenPropertiesToServer(payload: GetPayload<'tokensEdit'>) {
	getSocket().send('tokensEdit', payload);
}
