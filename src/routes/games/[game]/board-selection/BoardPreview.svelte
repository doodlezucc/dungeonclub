<script lang="ts">
	import { Button } from 'components';

	interface Props {
		name: string;
	}

	let { name }: Props = $props();
</script>

<Button on:click>{name}</Button>
