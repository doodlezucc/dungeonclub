<script lang="ts">
	import type { Size } from '$lib/compounds';
	import { boardState } from 'client/state';

	export const size: Size = {
		width: 600,
		height: 400
	};

	$: imgPath = $boardState!.mapImage.path;
</script>

<img
	alt="Battle map of this board"
	src={'/user-media/' + imgPath}
	width={size.width}
	height={size.height}
/>
