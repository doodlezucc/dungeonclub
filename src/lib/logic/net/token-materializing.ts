import type { OverridableTokenProperty, TokenProperties, TokenPropertiesOrNull } from './snippets';

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

export function getInheritedPropertiesOfToken(token: TokenPropertiesOrNull) {
	const result: OverridableTokenProperty[] = [];

	for (const propertyName of ALL_OVERRIDABLE_TOKEN_PROPERTIES) {
		if (token[propertyName] === null) {
			result.push(propertyName);
		}
	}

	return result;
}

export function extractPropertiesFromTemplate(
	template: TokenProperties,
	propertyNames: OverridableTokenProperty[]
) {
	const extractedProperties: Partial<TokenProperties> = {};

	for (const propertyName of propertyNames) {
		// @ts-expect-error - template[propertyName] is guaranteed to match the type, but is impossible to statically infer.
		extractedProperties[propertyName] = template[propertyName];
	}

	return extractedProperties;
}

export function applyTemplateInheritanceOnProperties(propertyNames: OverridableTokenProperty[]) {
	const extractedProperties: Partial<TokenPropertiesOrNull> = {};

	for (const propertyName of propertyNames) {
		extractedProperties[propertyName] = null;
	}

	return extractedProperties;
}
