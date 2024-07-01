<script lang="ts">
	import type { Size } from '$lib/compounds';
	import { Placeholder } from 'components/layout';

	export const size: Size = {
		width: 600,
		height: 400
	};
</script>

<Placeholder {size}>Battle Map</Placeholder>
