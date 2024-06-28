<script lang="ts">
	import Button from './Button.svelte';

	export let href: string;

	export let raised: boolean = false;
	export let type: HTMLButtonElement['type'] | undefined = undefined;
</script>

<a {href}>
	<Button {raised} {type}>
		<slot />
	</Button>
</a>
