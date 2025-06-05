<script lang="ts">
	import { Button } from 'components';
	import type { MouseEventHandler } from 'svelte/elements';

	interface Props {
		name: string;
		onclick: MouseEventHandler<HTMLElement>;
	}

	let { name, onclick }: Props = $props();
</script>

<Button {onclick}>{name}</Button>
