<script lang="ts" module>
	function findCommonValue<T>(values: T[]) {
		if (values.length == 0) return undefined;

		const commonValue = values[0];
		for (let i = 1; i < values.length; i++) {
			const value = values[i];

			if (value !== commonValue) {
				return undefined;
			}
		}

		return commonValue;
	}
</script>

<script lang="ts">
	import { Board, Campaign } from '$lib/client/state';
	import type { GetPayload, OverridableTokenProperty, TokenProperties } from '$lib/net';
	import { Column, Container, Input } from 'packages/ui';
	import { onMount } from 'svelte';
	import TokenPropertyAvatar from './TokenPropertyAvatar.svelte';
	import {
		arePayloadsEqual,
		buildWebSocketPayload,
		submitTokenPropertiesToServer
	} from './submitting';

	interface Props {
		selectedTokenIds: string[];
	}

	let { selectedTokenIds }: Props = $props();

	const allTokens = Board.instance.tokens;
	const allAssets = Campaign.instance.assets;

	const selectedTokens = $derived(
		selectedTokenIds.map((id) => $allTokens.find((token) => token.id === id)!)
	);

	const conflictOverrideProperties = $derived(selectedTokens[selectedTokens.length - 1]);

	const commonAvatarId = $derived(findCommonValue(selectedTokens.map((token) => token.avatarId)));
	const commonName = $derived(findCommonValue(selectedTokens.map((token) => token.name)));
	const commonSize = $derived(findCommonValue(selectedTokens.map((token) => token.size)));
	const commonInitiativeModifier = $derived(
		findCommonValue(selectedTokens.map((token) => token.initiativeModifier))
	);

	let displayedProperties: TokenProperties = $derived({
		avatarId: commonAvatarId !== undefined ? commonAvatarId : conflictOverrideProperties.avatarId,
		name: commonName ?? conflictOverrideProperties.name,
		size: commonSize ?? conflictOverrideProperties.size,
		initiativeModifier: commonInitiativeModifier ?? conflictOverrideProperties.initiativeModifier
	});

	function updatePropertyOnSelectedTokens<T extends OverridableTokenProperty>(
		property: T,
		value: TokenProperties[T]
	) {
		$allTokens = $allTokens.map((token) => {
			const isSelected = selectedTokens.some((selectedToken) => selectedToken.id === token.id);
			if (!isSelected) return token;

			return { ...token, [property]: value };
		});
	}

	function updatePropertyValue<T extends OverridableTokenProperty>(
		property: T,
		value: TokenProperties[T]
	) {
		if (value !== displayedProperties[property]) {
			displayedProperties = { ...displayedProperties, [property]: value };
			updatePropertyOnSelectedTokens(property, value);
		}
	}

	let avatarId = $derived(displayedProperties.avatarId);
	let avatar = $derived(avatarId ? $allAssets.find((asset) => asset.id === avatarId)! : null);

	let name = $derived(displayedProperties.name);
	let size = $derived(displayedProperties.size);
	let initiativeModifier = $derived(displayedProperties.initiativeModifier);

	let isMounted = $state(false);

	function buildEditingPayload(): GetPayload<'tokensEdit'> {
		return buildWebSocketPayload(selectedTokenIds, $allTokens);
	}

	let initialPayload = buildEditingPayload();

	function submitChanges() {
		const editedPayload = buildEditingPayload();

		if (!arePayloadsEqual(initialPayload, editedPayload)) {
			submitTokenPropertiesToServer(editedPayload);

			initialPayload = editedPayload;
		}
	}

	onMount(() => {
		isMounted = true;
	});
	$effect(() => {
		updatePropertyValue('name', name);
		updatePropertyValue('size', size);
		updatePropertyValue('initiativeModifier', initiativeModifier);

		updatePropertyValue('avatarId', avatar?.id ?? null);

		if (isMounted) {
			submitChanges();
		}
	});
</script>

<Container>
	<Column gap="normal">
		<Input name="name" bind:value={name} placeholder="Name..." size="small" />
		<TokenPropertyAvatar bind:avatar />
		<Input name="size" bind:value={size} type="number" placeholder="Size..." size="small" />
		<Input
			name="initiative-modifier"
			bind:value={initiativeModifier}
			type="number"
			placeholder="Initiative Modifier..."
			size="small"
		/>
	</Column>
</Container>
