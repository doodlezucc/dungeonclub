<script lang="ts">
	import { accountState } from '$lib/client/state';
	import AccountContent from '$lib/ui/home/AccountContent.svelte';
	import LoginForm from '$lib/ui/home/forms/LoginForm.svelte';
	import { Content, Row } from 'packages/ui';
	import { onMount } from 'svelte';
	import { fly, slide } from 'svelte/transition';

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
