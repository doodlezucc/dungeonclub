<script lang="ts">
	import { Button } from 'components';
	import { Column, Container } from 'components/layout';
	import { createEventDispatcher } from 'svelte';
	import { fly } from 'svelte/transition';

	export let title: string;
	export let submitButtonLabel: string;

	export let disableSubmitButton = false;

	export let errorReason = '';

	const dispatch = createEventDispatcher();
</script>

<div role="dialog">
	<Container margin="big" padding="big">
		<Column align="center">
			<h2>{title}</h2>

			<slot name="note" />

			<form action="javascript:void(0);" method="dialog" on:submit={() => false}>
				<slot />

				<span class="error" aria-live="polite" in:fly={{ y: 20 }}>{errorReason}</span>

				<Button
					type="submit"
					on:click={() => dispatch('submit')}
					raised
					highlight
					disabled={disableSubmitButton}
				>
					{submitButtonLabel}
				</Button>

				<slot name="links" />
			</form>
		</Column>
	</Container>
</div>

<style>
	h2 {
		color: var(--color-primary);
	}

	form {
		margin-top: 2em;
		display: grid;
		gap: 1em;
		max-width: 500px;
	}

	.error {
		margin-top: 0.5em;
		color: var(--color-bad);
	}

	span {
		justify-self: center;
	}
</style>
