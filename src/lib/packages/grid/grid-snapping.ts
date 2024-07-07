import type { Position } from '$lib/compounds';
import type { GridType } from '@prisma/client';

type PositionedSquare = {
	center: Position;
	size: number;
};

export interface SnapToGridProvider {
	snapShapeToGrid(token: PositionedSquare): Position;
}

export abstract class GridSpace implements SnapToGridProvider {
	abstract snapShapeToGrid(token: PositionedSquare): Position;

	static parse(gridType: GridType): GridSpace {
		switch (gridType) {
			case 'SQUARE':
				return SquareGridSpace.instance;
		}

		throw `No grid space implementation for type ${gridType}`;
	}
}

export class SquareGridSpace extends GridSpace {
	static readonly instance = new SquareGridSpace();

	snapShapeToGrid({ center: { x, y }, size }: PositionedSquare): Position {
		if (size % 2 == 1) {
			// Sizes 1, 3, 5 are centered in the middle of a grid cell
			return {
				x: Math.floor(x) + 0.5,
				y: Math.floor(y) + 0.5
			};
		} else {
			// Sizes 2, 4, 6 are centered on an intersection of grid cells
			return {
				x: Math.round(x),
				y: Math.round(y)
			};
		}
	}
}
