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
	import { Campaign } from 'client/state';
	import Icon from 'components/Icon.svelte';
	import Input from 'components/Input.svelte';
	import { Column, Container } from 'components/layout';
	import Row from 'components/layout/Row.svelte';
	import FileUploader from 'components/upload/FileUploader.svelte';
	import type { TokenSnippet } from 'shared';
	import {
		getAvatarUrlById,
		getTemplateForToken,
		materializeToken
	} from 'shared/token-materializing';
	import Inheritable from './Inheritable.svelte';

	export let selectedTokens: TokenSnippet[];

	const singleTokenTemplate = getCommonTokenTemplate(selectedTokens);

	const canToggleInheritance = singleTokenTemplate !== null;

	const allTemplates = Campaign.instance.tokenTemplates;
	const materializedTokens = selectedTokens.map((token) =>
		materializeToken(token, getTemplateForToken(token, $allTemplates))
	);

	const conflictOverrideProperties = materializedTokens[materializedTokens.length - 1];

	function doAllTokensInherit<T>(getProperty: (token: TokenSnippet) => T | null) {
		const doesAnyTokenOverride = selectedTokens.some((token) => getProperty(token) !== null);
		return !doesAnyTokenOverride;
	}

	const commonAvatarId = findAverageOfStrings(materializedTokens.map((token) => token.avatarId));
	let avatarId =
		commonAvatarId !== undefined ? commonAvatarId : conflictOverrideProperties.avatarId;
	let inheritAvatar = doAllTokensInherit((token) => token.avatar);
	let enteredInheritAvatar = inheritAvatar;

	let avatar = avatarId ? getAvatarUrlById(avatarId, selectedTokens, $allTemplates) : null;

	const commonName = findAverageOfStrings(materializedTokens.map((token) => token.name));
	let name = commonName ?? conflictOverrideProperties.name;
	let inheritName = doAllTokensInherit((token) => token.name);
	let enteredName = name;
	let enteredInheritName = inheritName;

	$: {
		if (enteredInheritName !== inheritName) {
			inheritName = enteredInheritName;

			if (enteredInheritName) {
				console.log('Apply to template');
			} else {
				console.log('Detach');
			}
		}
	}
</script>

<Container>
	<Column gap="normal">
		<Inheritable bind:isInheriting={enteredInheritName} disableToggle={!canToggleInheritance}>
			<Input name="name" bind:value={enteredName} placeholder="Name..." size="small" />
		</Inheritable>

		<Inheritable bind:isInheriting={enteredInheritAvatar} disableToggle={!canToggleInheritance}>
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
