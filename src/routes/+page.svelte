<script>
	import { account } from '$lib/client/socket';
	import Content from '$lib/kit/Content.svelte';
	import Row from '$lib/kit/layout/Row.svelte';
	import { onMount } from 'svelte';
	import { fly, slide } from 'svelte/transition';
	import AccountContent from './AccountContent.svelte';
	import LoginForm from './LoginForm.svelte';

	$: isLoggedIn = !!$account;

	$: isMounted = false;

	onMount(() => (isMounted = true));
</script>

<Content>
	{#if !isLoggedIn && isMounted}
		<div in:fly={{ y: 50, duration: 800 }} out:slide>
			<Row justify="center">
				<LoginForm />
			</Row>
		</div>
	{:else if isMounted}
		<AccountContent></AccountContent>
	{/if}
</Content>
