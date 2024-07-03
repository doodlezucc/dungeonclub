<script>
	import { accountState } from '$lib/client/state';
	import { Content } from 'components';
	import { Row } from 'components/layout';
	import { onMount } from 'svelte';
	import { fly, slide } from 'svelte/transition';
	import AccountContent from './home/AccountContent.svelte';
	import LoginForm from './home/LoginForm.svelte';

	$: isLoggedIn = !!$accountState;

	$: isMounted = false;

	onMount(() => (isMounted = true));
</script>

<main>
	<Content>
		{#if !isLoggedIn && isMounted}
			<div in:fly={{ y: 50, duration: 800 }} out:slide>
				<Row justify="center">
					<LoginForm />
				</Row>
			</div>
		{:else if isMounted}
			<AccountContent />
		{/if}
	</Content>
</main>

<style>
	main {
		padding: 2em 0;
	}
</style>
