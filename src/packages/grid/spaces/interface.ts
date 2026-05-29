import type { Point } from 'packages/math';

export type PositionedSquare = {
	center: Point;
	size: number;
};

export abstract class GridSpace {
	abstract get tileHeightRatio(): number;
	protected abstract snapShapeToGridUnstretched(token: PositionedSquare): Point;

	snapShapeToGrid(token: PositionedSquare): Point {
		const unstretched = this.snapShapeToGridUnstretched(token);
		return {
			x: unstretched.x,
			y: unstretched.y * this.tileHeightRatio
		};
	}
}
