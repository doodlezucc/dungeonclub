<script lang="ts">
	import Overlay from '$lib/kit/layout/Overlay.svelte';
	import PanView from '$lib/kit/PanView.svelte';
	import BattleMap from './BattleMap.svelte';
	import Grid from './Grid.svelte';
</script>

<PanView expand>
	<div class="board">
		<BattleMap />
		<Overlay><Grid /></Overlay>
	</div>
</PanView>

<style>
	.board {
		position: relative;
		display: flex;
		align-self: center;
	}
</style>
