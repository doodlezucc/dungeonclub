<script lang="ts">
	import { Button } from 'components';
	import { Column, Container } from 'components/layout';
	import { fly } from 'svelte/transition';

	export let title: string;
	export let submitButtonLabel: string;

	export let disableSubmitButton = false;
	export let disableFormSpacing = false;

	export let handleSubmit: () => Promise<void>;

	$: errorReason = '';
	$: errorIndex = 0;
	$: isSubmitting = false;

	async function onSubmitForm() {
		isSubmitting = true;
		errorReason = '';

		try {
			await handleSubmit();
		} catch (err) {
			errorReason = `${err}`;
			errorIndex++;
		} finally {
			isSubmitting = false;
		}
	}
</script>

<div role="dialog">
	<Container margin="big" padding="big">
		<Column align="center">
			<h2>{title}</h2>

			<slot name="note" />

			<form
				class:disable-spacing={disableFormSpacing}
				action="javascript:void(0);"
				method="dialog"
				on:submit={() => false}
			>
				<slot />

				{#key errorIndex}
					<span class="error" aria-live="polite" in:fly={{ y: 20 }}>{errorReason}</span>
				{/key}

				<Button
					type="submit"
					on:click={onSubmitForm}
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

	.error {
		margin-top: 0.5em;
		color: var(--color-bad);
	}

	.disable-spacing {
		margin-top: 0;
		gap: 0.5em;

		.error {
			margin-top: 0;
		}
	}
</style>
