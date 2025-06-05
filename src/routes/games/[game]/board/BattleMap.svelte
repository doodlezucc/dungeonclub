<script lang="ts">
	import type { Size } from '$lib/compounds';
	import { asset } from 'client/communication/asset';
	import { boardState, Campaign } from 'client/state';

	interface Props {
		/** Read-only. */
		size?: Size;
	}

	let { size = $bindable() }: Props = $props();

	let width = $state<number>();
	let height = $state<number>();

	$effect(() => {
		if (width !== undefined && height !== undefined) {
			size = { width: width, height: height };
		}
	});

	let boardImageAsset = $derived(Campaign.instance.assetById($boardState!.mapImageId));
</script>

<img
	alt="Battle map of this board"
	src={asset($boardImageAsset.path)}
	bind:naturalWidth={width}
	bind:naturalHeight={height}
/>
