<script lang="ts" context="module">
	function getCommonTokenTemplate(tokens: TokenSnippet[]) {
		if (tokens.length == 0) return null;

		const commonTemplateId = tokens[0].templateId;
		for (let i = 1; i < tokens.length; i++) {
			const tokenInstance = tokens[i];

			if (tokenInstance.templateId !== commonTemplateId) {
				return null;
			}
		}

		return commonTemplateId;
	}

	function findAverageOfStrings<T = string>(strings: T[]) {
		if (strings.length == 0) return '';

		const commonString = strings[0];
		for (let i = 1; i < strings.length; i++) {
			const stringInstance = strings[i];

			if (stringInstance !== commonString) {
				return undefined;
			}
		}

		return commonString;
	}
</script>

<script lang="ts">
	import { asset } from 'client/communication/asset';
	import { Board, Campaign } from 'client/state';
	import Icon from 'components/Icon.svelte';
	import Input from 'components/Input.svelte';
	import { Column, Container } from 'components/layout';
	import Row from 'components/layout/Row.svelte';
	import FileUploader from 'components/upload/FileUploader.svelte';
	import type { OverridableTokenProperty, TokenSnippet, TokenTemplateSnippet } from 'shared';
	import {
		getAvatarUrlById,
		getTemplateForToken,
		materializeToken
	} from 'shared/token-materializing';
	import Inheritable from './Inheritable.svelte';

	export let selectedTokens: TokenSnippet[];

	const allTokens = Board.instance.tokens;
	const allTemplates = Campaign.instance.tokenTemplates;
	const singleTokenTemplateId = getCommonTokenTemplate(selectedTokens);

	const canToggleInheritance = singleTokenTemplateId !== null;

	const materializedTokens = selectedTokens.map((token) =>
		materializeToken(token, getTemplateForToken(token, $allTemplates))
	);

	function doAllTokensInherit<T>(getProperty: (token: TokenSnippet) => T | null) {
		const doesAnyTokenOverride = selectedTokens.some((token) => getProperty(token) !== null);
		return !doesAnyTokenOverride;
	}

	const conflictOverrideProperties = materializedTokens[materializedTokens.length - 1];

	const commonAvatarId = findAverageOfStrings(materializedTokens.map((token) => token.avatarId));
	let avatarId =
		commonAvatarId !== undefined ? commonAvatarId : conflictOverrideProperties.avatarId;
	let inheritAvatar = doAllTokensInherit((token) => token.avatar);
	let inheritAvatarValue = inheritAvatar;

	let avatar = avatarId ? getAvatarUrlById(avatarId, selectedTokens, $allTemplates) : null;

	const commonName = findAverageOfStrings(materializedTokens.map((token) => token.name));
	let name = commonName ?? conflictOverrideProperties.name;
	let nameValue = name;

	let inheritName = doAllTokensInherit((token) => token.name);
	let inheritNameValue = inheritName;

	function updateTemplateProperty(
		updater: (template: TokenTemplateSnippet) => TokenTemplateSnippet
	) {
		$allTemplates = $allTemplates.map((template) => {
			if (template.id !== singleTokenTemplateId) return template;

			return updater(template);
		});
	}

	function updatePropertyOnSelectedTokens(updater: (token: TokenSnippet) => TokenSnippet) {
		$allTokens = $allTokens.map((token) => {
			if (!selectedTokens.includes(token)) return token;

			return updater(token);
		});
	}

	function unsetPropertyOnSelectedTokens(property: OverridableTokenProperty) {
		updatePropertyOnSelectedTokens((token) => ({
			...token,
			[property]: null
		}));
	}

	$: {
		if (nameValue !== name) {
			name = nameValue;

			if (inheritName) {
				// Update template
				updateTemplateProperty((template) => ({
					...template,
					name: name
				}));
			} else {
				// Update token instance
				updatePropertyOnSelectedTokens((token) => ({
					...token,
					name: name
				}));
			}
		}

		if (inheritNameValue !== inheritName) {
			inheritName = inheritNameValue;

			if (inheritName) {
				// Assertion: `singleTokenTemplate` != null
				// Apply name to template and all
				updateTemplateProperty((template) => ({
					...template,
					name: name
				}));
				unsetPropertyOnSelectedTokens('name');
			} else {
				console.log('Detach');
				updatePropertyOnSelectedTokens((token) => ({
					...token,
					name: name
				}));
			}
		}
	}
</script>

<Container>
	<Column gap="normal">
		<Inheritable bind:isInheriting={inheritNameValue} disableToggle={!canToggleInheritance}>
			<Input name="name" bind:value={nameValue} placeholder="Name..." size="small" />
		</Inheritable>

		<Inheritable bind:isInheriting={inheritAvatarValue} disableToggle={!canToggleInheritance}>
			<FileUploader accept="image/*" buttonClass="token-properties-avatar-upload">
				<Row align="center">
					{#if avatar}
						<img src={asset(avatar.path)} alt="Token avatar" />
					{:else}
						<Icon icon="user" />
					{/if}

					<span class="avatar-label">Avatar</span>
				</Row>
			</FileUploader>
		</Inheritable>
	</Column>
</Container>

<style lang="scss">
	$avatar-size: 48px;

	:global(.token-properties-avatar-upload) {
		padding: 0;
		overflow: hidden;
		border-radius: $avatar-size;
		flex: 1;

		font: inherit;
		letter-spacing: inherit;
		text-transform: none;
		color: inherit;
	}

	:global(.token-properties-avatar-upload:hover) {
		border: 2px solid var(--color-input-hover-outline);
	}

	.avatar-label {
		margin: 0 16px 0 8px;
	}

	img {
		display: block;
		width: $avatar-size;
		height: $avatar-size;
		border-radius: 50%;
		object-fit: cover;
	}
</style>
