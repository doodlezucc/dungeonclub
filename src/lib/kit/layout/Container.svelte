<script lang="ts" context="module">
	export type Padding = 'big';
	export type Margin = 'big';
</script>

<script lang="ts">
	export let margin: Margin | undefined = undefined;
	export let padding: Padding | undefined = undefined;
</script>

<div class="container" data-margin={margin} data-padding={padding}>
	<slot />
</div>
