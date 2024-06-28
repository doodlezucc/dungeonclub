<script lang="ts" context="module">
	export type Padding = 'big';
</script>

<script lang="ts">
	export let padding: Padding | undefined = undefined;
</script>

<div class="container" data-padding={padding}>
	<slot />
</div>
