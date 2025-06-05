<script lang="ts">
	import { Button } from 'components';
	import { Column, Container } from 'components/layout';
	import type { Snippet } from 'svelte';
	import { fly } from 'svelte/transition';

	interface Props {
		title: string;
		submitButtonLabel: string;
		disableSubmitButton?: boolean;
		disableFormSpacing?: boolean;
		handleSubmit: () => Promise<void>;
		note?: Snippet;
		children?: Snippet;
		links?: Snippet;
	}

	let {
		title,
		submitButtonLabel,
		disableSubmitButton = false,
		disableFormSpacing = false,
		handleSubmit,
		note,
		children,
		links
	}: Props = $props();

	let errorReason = $state('');

	let isSubmitting = $state(false);

	async function onSubmitForm() {
		isSubmitting = true;
		errorReason = '';

		try {
			await handleSubmit();
		} catch (err) {
			if (err instanceof Error) {
				errorReason = err.message;
			} else {
				errorReason = `${err}`;
			}
		} finally {
			isSubmitting = false;
		}
	}
</script>

<div role="dialog">
	<Container margin="big" padding="big">
		<Column align="center">
			<h2>{title}</h2>

			{@render note?.()}

			<form
				class:disable-spacing={disableFormSpacing}
				action="javascript:void(0);"
				method="dialog"
				onsubmit={() => false}
			>
				{@render children?.()}

				{#if errorReason}
					<span class="error" aria-live="polite" in:fly={{ y: 20 }}>{errorReason}.</span>
				{/if}

				<Button
					type="submit"
					onclick={onSubmitForm}
					raised
					highlight
					disabled={isSubmitting || disableSubmitButton}
				>
					{submitButtonLabel}
				</Button>

				{@render links?.()}
			</form>
		</Column>
	</Container>
</div>

<style lang="scss">
	h2 {
		color: var(--color-primary);
	}

	form {
		margin-top: 2em;
		display: grid;
		gap: 1em;
		max-width: 500px;
		text-align: center;
	}

	:global(form .error) {
		text-align: start;

		/* Prevent validation text from expanding the form width. */
		width: 0;
		min-width: 100%;
	}

	.error {
		margin-top: 0.5em;
	}

	.disable-spacing {
		margin-top: 0;
		gap: 0.5em;

		.error {
			margin-top: 0;
		}
	}
</style>
