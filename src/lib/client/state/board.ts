import { writable } from 'svelte/store';

export const board = writable<Board | null>(null);

export class Board {
	grid: BoardGrid;

	constructor(grid: BoardGrid) {
		this.grid = grid;
	}
}

export interface BoardGridState {}

export class BoardGrid {
	cellsPerRow: number;

	constructor(cellsPerRow: number) {
		this.cellsPerRow = cellsPerRow;
	}
}
