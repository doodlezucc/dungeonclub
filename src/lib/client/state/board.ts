import type { BoardSnippet } from '$lib/net';
import { WithState } from './with-state';

export class BoardGrid {
	constructor(readonly board: Board) {}
}

export class Board extends WithState<BoardSnippet> {
	static readonly instance = new Board();
	static readonly state = this.instance.state;

	readonly grid = new BoardGrid(this);
}

export const boardState = Board.state;
