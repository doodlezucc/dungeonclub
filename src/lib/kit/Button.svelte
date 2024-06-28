<script lang="ts">
	export let raised: boolean = false;
	export let disabled: boolean = false;
	export let type: HTMLButtonElement['type'] | undefined = undefined;
</script>

<button on:click class:raised {disabled} {type}>
	<slot />
</button>
