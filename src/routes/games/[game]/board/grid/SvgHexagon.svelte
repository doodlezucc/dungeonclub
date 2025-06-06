<script lang="ts" module>
	import type { HexGridSpace } from 'packages/grid/spaces/hex';
	import type { Position } from 'packages/ui/compounds';

	function drawPolygon(offset: Position, scale: number, gridSpace: HexGridSpace): Position[] {
		const unitHexagon = gridSpace.getUnitHexagonShape();

		return unitHexagon.points.map((point) => ({
			x: (point.x + offset.x) * scale,
			y: (point.y + offset.y) * scale * gridSpace.tileHeightRatio
		}));
	}

	function makePolygonData(points: Position[]) {
		return points.map((point) => `${point.x},${point.y}`).join(' ');
	}
</script>

<script lang="ts">
	interface Props {
		offset: Position;
		cellWidth: number;
		gridSpace: HexGridSpace;
	}

	let { offset, cellWidth, gridSpace }: Props = $props();

	let points = $derived(drawPolygon(offset, cellWidth, gridSpace));
</script>

<polygon id="hexagon" points={makePolygonData(points)} />
