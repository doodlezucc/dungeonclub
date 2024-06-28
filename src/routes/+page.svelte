<script>
	import { account } from '$lib/client/socket';
	import Content from '$lib/kit/Content.svelte';
	import { onMount } from 'svelte';
	import CampaignCard from './CampaignCard.svelte';

	$: isLoggedIn = !!$account;

	$: isMounted = false;

	onMount(() => (isMounted = true));
</script>

<main>
	<Content>
		<!-- {#if !isLoggedIn && isMounted}
			<div in:fly={{ y: 50, duration: 800 }} out:slide>
				<Row justify="center">
					<LoginForm />
				</Row>
			</div>
		{:else if isMounted}
			<AccountContent></AccountContent>
		{/if} -->

		<CampaignCard snippet={{ id: 'id', name: 'Short', createdAt: new Date() }} />
		<CampaignCard
			snippet={{ id: 'id', name: 'A long name, akin to a lorem ipsum', createdAt: new Date() }}
		/>
	</Content>
</main>

<style>
	main {
		padding: 2em 0;
	}
</style>
