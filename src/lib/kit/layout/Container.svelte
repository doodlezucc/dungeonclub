<script lang="ts" context="module">
	export type FlexDirection = 'column' | 'row';
</script>

<script lang="ts">
	export let direction: FlexDirection | undefined = undefined;
	export let expand = false;
</script>

<div class={direction} class:expand>
	<slot />
</div>
