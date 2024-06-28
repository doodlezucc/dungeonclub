<script>
	import Content from '$lib/kit/Content.svelte';
	import Row from '$lib/kit/layout/Row.svelte';
	import LoginForm from './LoginForm.svelte';
</script>

<Content>
	<h1>Home!</h1>

	<Row justify="center">
		<LoginForm />
	</Row>
</Content>
