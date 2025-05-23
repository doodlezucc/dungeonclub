<script lang="ts">
	import type { Size } from '$lib/compounds';
	import { asset } from 'client/communication/asset';
	import { boardState, Campaign } from 'client/state';

	interface Props {
		/** Read-only. */
		size?: Size;
	}

	let {
		size = $bindable({
			width: 600,
			height: 400
		})
	}: Props = $props();

	let boardImageAsset = $derived(Campaign.instance.assetById($boardState!.mapImageId));
</script>

<img
	alt="Battle map of this board"
	src={asset($boardImageAsset.path)}
	width={size.width}
	height={size.height}
/>
