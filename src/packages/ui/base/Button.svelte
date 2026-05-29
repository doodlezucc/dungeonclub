<script lang="ts">
	import { goto } from '$app/navigation';
	import type { Snippet } from 'svelte';
	import type { MouseEventHandler } from 'svelte/elements';

	interface Props {
		href?: string | undefined;
		highlight?: boolean;
		raised?: boolean;
		disabled?: boolean;
		type?: HTMLButtonElement['type'] | undefined;

		onclick?: MouseEventHandler<HTMLElement>;

		children?: Snippet;
	}

	let {
		href = undefined,
		highlight = false,
		raised = false,
		disabled = false,
		type = undefined,
		onclick,
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
	{onclick}
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
