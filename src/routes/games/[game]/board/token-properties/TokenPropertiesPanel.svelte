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

	function findAverageOfStrings(strings: string[]) {
		if (strings.length == 0) return '';

		const commonString = strings[0];
		for (let i = 1; i < strings.length; i++) {
			const stringInstance = strings[i];

			if (stringInstance !== commonString) {
				return null;
			}
		}

		return commonString;
	}
</script>

<script lang="ts">
	import { Campaign } from 'client/state';
	import Input from 'components/Input.svelte';
	import { Column } from 'components/layout';
	import type { TokenSnippet } from 'shared';
	import { getTemplateForToken, materializeToken } from 'shared/token-materializing';
	import Panel from '../Panel.svelte';
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

<Panel title="Token Properties">
	<Column gap="normal">
		<Inheritable bind:isInheriting={enteredInheritName} disableToggle={!canToggleInheritance}>
			<Input name="name" bind:value={enteredName} placeholder="Name..." size="small" />
		</Inheritable>
	</Column>
</Panel>
