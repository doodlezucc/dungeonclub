<script lang="ts">
	import { Campaign } from 'client/state';
	import Input from 'components/Input.svelte';
	import { Column } from 'components/layout';
	import type { TokenSnippet } from 'shared';
	import Panel from '../Panel.svelte';
	import Inheritable from './Inheritable.svelte';

	export let token: TokenSnippet;

	const allTemplates = Campaign.instance.tokenTemplates;
	$: tokenTemplate = token.templateId
		? $allTemplates.find((template) => template.id === token.templateId)!
		: null;

	let enteredName: string = token.name ?? tokenTemplate!.name;
	let inheritName: boolean = token.name === null;
</script>

<Panel title="Token Properties">
	<Column gap="normal">
		<Inheritable bind:isInheriting={inheritName}>
			<Input name="name" bind:value={enteredName} placeholder="Name..." size="small" />
		</Inheritable>
	</Column>
</Panel>
