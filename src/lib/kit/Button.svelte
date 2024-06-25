<script lang="ts">
	export let disabled: boolean = false;
	export let raised: boolean = false;
</script>

<button on:click {disabled} class:raised>
	<slot />
</button>
