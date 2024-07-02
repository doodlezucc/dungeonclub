<script lang="ts" context="module">
	import { library } from '@fortawesome/fontawesome-svg-core';
	import { fab } from '@fortawesome/free-brands-svg-icons';
	import { fas } from '@fortawesome/free-solid-svg-icons';
	import type { FontAwesomeIconProps } from '@fortawesome/svelte-fontawesome';

	export type IconID = FontAwesomeIconProps['icon'];

	library.add(fas, fab);
</script>

<script lang="ts">
	import { FontAwesomeIcon } from '@fortawesome/svelte-fontawesome';

	export let icon: IconID;
</script>

<FontAwesomeIcon {icon} />
