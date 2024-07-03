import type { BoardSnippet } from 'shared';
import { getSocket } from '../communication';
import { WithState } from './with-state';

export class BoardGrid {
	constructor(readonly board: Board) {}
}

export class Board extends WithState<BoardSnippet> {
	static readonly instance = new Board();
	static readonly state = this.instance.state;

	readonly grid = new BoardGrid(this);

	load(snippet: BoardSnippet) {
		this.set(snippet);
	}

	async view(boardId: string) {
		const board = await getSocket().request('boardView', { id: boardId });
		this.load(board);
	}
}

export const boardState = Board.state;
