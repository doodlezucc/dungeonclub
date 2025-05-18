<script lang="ts">
	import { createBubbler } from 'svelte/legacy';

	const bubble = createBubbler();
	import { goto } from '$app/navigation';



	interface Props {
		href?: string | undefined;
		highlight?: boolean;
		raised?: boolean;
		disabled?: boolean;
		type?: HTMLButtonElement['type'] | undefined;
		children?: import('svelte').Snippet;
	}

	let {
		href = undefined,
		highlight = false,
		raised = false,
		disabled = false,
		type = undefined,
		children
	}: Props = $props();

	function handleSpaceBar(ev: KeyboardEvent) {
		if (ev.key === ' ') {
			goto(href!);
		}
	}
</script>

<svelte:element
	this={href ? 'a' : 'button'}
	onclick={bubble('click')}
	onkeypress={href ? handleSpaceBar : undefined}
	{href}
	role={href && 'button'}
	class:action={highlight}
	class:raised
	{disabled}
	{type}
>
	{@render children?.()}
</svelte:element>
