import type { OverridableTokenProperty, TokenProperties } from './snippets';

// When adding overridable token properties to prisma.schema, TypeScript requires the property to be explicitly added here.
// This makes it possible to have the unique set of overridable properties as CONSTANTS, as opposed to just TYPES.
const UNIQUE_OVERRIDABLE_TOKEN_PROPERTIES: Record<OverridableTokenProperty, true> = {
	avatarId: true,
	initiativeModifier: true,
	name: true,
	size: true
};

export const ALL_OVERRIDABLE_TOKEN_PROPERTIES = Object.keys(
	UNIQUE_OVERRIDABLE_TOKEN_PROPERTIES
) as OverridableTokenProperty[];

export const EMPTY_TOKEN_PROPERTIES: TokenProperties = {
	avatarId: null,
	initiativeModifier: 0,
	name: 'Token',
	size: 1
};
