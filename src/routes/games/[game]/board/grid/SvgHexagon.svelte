<script lang="ts" context="module">
	import type { Position } from 'components/compounds';

	const oneThird = 1 / 3;
	const heightRatio = 0.8660254037844386;

	const unitHexagonHorizontal: Position[] = [
		{ x: -oneThird, y: -0.5 },
		{ x: oneThird, y: -0.5 },
		{ x: 2 * oneThird, y: 0 },
		{ x: oneThird, y: 0.5 },
		{ x: -oneThird, y: 0.5 },
		{ x: -2 * oneThird, y: 0 }
	];

	function drawPolygon(offset: Position, scale: number): Position[] {
		return unitHexagonHorizontal.map((point) => ({
			x: (point.x + offset.x) * scale,
			y: ((point.y + offset.y) * scale) / heightRatio
		}));
	}

	function makePolygonData(points: Position[]) {
		return points.map((point) => `${point.x},${point.y}`).join(' ');
	}
</script>

<script lang="ts">
	export let offset: Position;
	export let cellWidth: number;

	$: points = drawPolygon(offset, cellWidth);
</script>

<polygon id="hexagon" points={makePolygonData(points)} />
