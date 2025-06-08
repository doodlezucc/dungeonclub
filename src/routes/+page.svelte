<script lang="ts">
	import { accountState } from '$lib/client/state';
	import { Content, Row } from 'packages/ui';
	import { onMount } from 'svelte';
	import { fly, slide } from 'svelte/transition';
	import AccountContent from './home/AccountContent.svelte';
	import LoginForm from './home/forms/LoginForm.svelte';

	let isLoggedIn = $derived(!!$accountState);

	let isMounted = $state(false);

	onMount(() => {
		isMounted = true;
	});
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
