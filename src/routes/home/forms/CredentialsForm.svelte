<script lang="ts">
	import Input from 'components/Input.svelte';
	import { Column } from 'components/layout';
	import { enteredEmailAddress } from '../credential-stores';
	import Form from './Form.svelte';

	export let title: string;
	export let submitButtonLabel: string;
	export let passwordInputLabel = 'Password';

	export let handleSubmit: (emailAddress: string, password: string) => Promise<void>;

	$: password = '';
	$: passwordConfirmation = '';

	$: isValid = $enteredEmailAddress.length > 0 && password === passwordConfirmation;
</script>

<Form
	{title}
	{submitButtonLabel}
	disableSubmitButton={!isValid}
	handleSubmit={() => handleSubmit($enteredEmailAddress, password)}
>
	<slot name="note" slot="note"></slot>

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
	</Column>

	<slot name="links" slot="links"></slot>
</Form>
