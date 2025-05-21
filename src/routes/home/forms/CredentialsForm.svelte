<script lang="ts" module>
	const MIN_PASSWORD_LENGTH = 7;
</script>

<script lang="ts">
	import { run } from 'svelte/legacy';

	import Input from 'components/Input.svelte';
	import { Column } from 'components/layout';
	import type { Snippet } from 'svelte';
	import { enteredEmailAddress } from '../credential-stores';
	import Form from './Form.svelte';

	interface Props {
		title: string;
		submitButtonLabel: string;
		passwordInputLabel?: string;
		handleSubmit: (emailAddress: string, password: string) => Promise<void>;
		note?: Snippet;
		links?: Snippet;
	}

	let {
		title,
		submitButtonLabel,
		passwordInputLabel = 'Password',
		handleSubmit,
		note,
		links
	}: Props = $props();

	let password = $state('');

	let passwordConfirmation = $state('');

	let formValidationError = $state('woah');

	let isValid = $state(false);

	function validate() {
		if (password.length === 0) {
			throw '';
		}

		if (password.length < MIN_PASSWORD_LENGTH) {
			throw `Password should be at least ${MIN_PASSWORD_LENGTH} characters long.`;
		}

		if (passwordConfirmation.length > 0 && password !== passwordConfirmation) {
			throw "Passwords don't match.";
		}

		if ($enteredEmailAddress.length === 0 || passwordConfirmation.length === 0) {
			throw '';
		}
	}

	run(() => {
		[$enteredEmailAddress, password, passwordConfirmation];

		isValid = false;

		try {
			validate();
			formValidationError = '';
			isValid = true;
		} catch (err) {
			formValidationError = `${err}`;
		}
	});
</script>

<Form
	{title}
	{submitButtonLabel}
	disableSubmitButton={!isValid}
	handleSubmit={() => handleSubmit($enteredEmailAddress, password)}
	{note}
	{links}
>
	<Input
		autofocus
		required
		label="Email Address"
		placeholder="Email of your account..."
		name="email"
		type="email"
		autocomplete="email"
		bind:value={$enteredEmailAddress}
	/>
	<Column gap="normal">
		<Input
			required
			label={passwordInputLabel}
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
		{#if formValidationError.length > 0}
			<span class="error">{formValidationError}</span>
		{/if}
	</Column>
</Form>
