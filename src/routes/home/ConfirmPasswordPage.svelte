<script lang="ts">
	import Input from 'components/Input.svelte';
	import { Column } from 'components/layout';
	import Form from './Form.svelte';

	export let title: string;
	export let submitButtonLabel: string;

	export let emailAddress = '';
	export let password = '';
	export let passwordConfirmation = '';

	export let errorReason = '';

	$: {
		if (emailAddress && password) {
			errorReason = '';
		}
	}

	$: isValid = emailAddress.length > 0 && password === passwordConfirmation;
</script>

<main>
	<Form {title} {submitButtonLabel} {errorReason} disableSubmitButton={!isValid} on:submit>
		<slot name="note" slot="note"></slot>

		<Input
			autofocus
			required
			label="Email Address"
			placeholder="Email of your account..."
			name="email"
			type="email"
			autocomplete="email"
			bind:value={emailAddress}
		/>
		<Column gap="normal">
			<Input
				required
				label="Password"
				placeholder="Password..."
				name="new-password"
				type="password"
				autocomplete="new-password"
				bind:value={password}
			/>
			<Input
				required
				placeholder="Password (again)..."
				name="confirm-password"
				type="password"
				autocomplete="new-password"
				bind:value={passwordConfirmation}
			/>
		</Column>

		<slot name="links" slot="links"></slot>
	</Form>
</main>

<style>
	main {
		display: grid;
		justify-content: center;
	}
</style>
