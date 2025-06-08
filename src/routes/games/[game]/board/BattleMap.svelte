<script lang="ts">
	import { asset } from '$lib/client/communication/asset';
	import { boardState, Campaign } from '$lib/client/state';
	import type { Size } from 'packages/math';

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
