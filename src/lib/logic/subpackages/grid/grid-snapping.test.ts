import type { Position } from 'components/compounds';
import { describe, expect, test } from 'vitest';
import { SquareGridSpace } from './grid-snapping';

function expectApproximatePosition(received: Position, expected: Position) {
	return expect(received).toEqual({
		x: expect.closeTo(expected.x),
		y: expect.closeTo(expected.y)
	});
}

describe('Square Grid', () => {
	const gridSpace = new SquareGridSpace();

	test('Snap token of size 1 or 3', () => {
		function expectSnapped(raw: Position, expected: Position) {
			expectApproximatePosition(gridSpace.snapShapeToGrid({ size: 1, center: raw }), expected);
			expectApproximatePosition(gridSpace.snapShapeToGrid({ size: 3, center: raw }), expected);
		}

		expectSnapped({ x: 0.1, y: 0.1 }, { x: 0.5, y: 0.5 });
		expectSnapped({ x: 0.1, y: -0.1 }, { x: 0.5, y: -0.5 });
		expectSnapped({ x: 2.5, y: 3.5 }, { x: 2.5, y: 3.5 });
		expectSnapped({ x: -1.9, y: 3.9 }, { x: -1.5, y: 3.5 });
		expectSnapped({ x: 2.1, y: -4.1 }, { x: 2.5, y: -4.5 });
	});

	test('Snap token of size 0, 2 or 4', () => {
		function expectSnapped(raw: Position, expected: Position) {
			expectApproximatePosition(gridSpace.snapShapeToGrid({ size: 0, center: raw }), expected);
			expectApproximatePosition(gridSpace.snapShapeToGrid({ size: 2, center: raw }), expected);
			expectApproximatePosition(gridSpace.snapShapeToGrid({ size: 4, center: raw }), expected);
		}

		expectSnapped({ x: 0.1, y: 0.1 }, { x: 0, y: 0 });
		expectSnapped({ x: 0.1, y: -0.1 }, { x: 0, y: 0 });
		expectSnapped({ x: 2.4, y: 3.4 }, { x: 2, y: 3 });
		expectSnapped({ x: -1.9, y: 3.9 }, { x: -2, y: 4 });
		expectSnapped({ x: 2.1, y: -4.1 }, { x: 2, y: -4 });
	});
});
