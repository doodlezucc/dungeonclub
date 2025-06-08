<script lang="ts" module>
	const MIN_PASSWORD_LENGTH = 7;
</script>

<script lang="ts">
	import { Column, Input } from 'packages/ui';
	import { onMount, type Snippet } from 'svelte';
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

	let formValidationError = $state('');

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

	function updateFormValidation() {
		isValid = false;

		try {
			validate();
			formValidationError = '';
			isValid = true;
		} catch (err) {
			formValidationError = `${err}`;
		}
	}

	onMount(() => {
		updateFormValidation();
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
		onInput={updateFormValidation}
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
			onInput={updateFormValidation}
		/>
		<Input
			required
			placeholder="Password (again)..."
			name="confirm-password"
			type="password"
			autocomplete="new-password"
			bind:value={passwordConfirmation}
			onInput={updateFormValidation}
		/>
		{#if formValidationError.length > 0}
			<span class="error">{formValidationError}</span>
		{/if}
	</Column>
</Form>
