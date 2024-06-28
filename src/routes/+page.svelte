<script>
	import Content from '$lib/kit/Content.svelte';
	import Row from '$lib/kit/layout/Row.svelte';
	import { onMount } from 'svelte';
	import { fly } from 'svelte/transition';
	import AccountContent from './AccountContent.svelte';
	import LoginForm from './LoginForm.svelte';

	// $: showLoginForm = !$isLoggedIn;
	$: showLoginForm = false;

	$: isMounted = false;

	onMount(() => (isMounted = true));
</script>

<Content>
	<h1>Home!</h1>

	<Row justify="center">
		{#if showLoginForm && isMounted}
			<div transition:fly={{ y: 50, duration: 800 }}>
				<LoginForm />
			</div>
		{/if}
	</Row>

	{#if isMounted}
		<AccountContent></AccountContent>
	{/if}
</Content>
