import type { BoardSnippet } from 'shared';
import { getSocket } from '../communication';
import { WithState } from './with-state';

export class BoardGrid {
	constructor(readonly board: Board) {}
}

export interface BoardSelectOptions {
	boardId: string;
	mode: 'edit' | 'play';
}

export class Board extends WithState<BoardSnippet> {
	static readonly instance = new Board();
	static readonly state = this.instance.state;

	readonly grid = new BoardGrid(this);

	load(snippet: BoardSnippet) {
		this.set(snippet);
	}

	async request({ boardId, mode }: BoardSelectOptions) {
		let snippet: BoardSnippet;

		if (mode === 'edit') {
			snippet = await getSocket().request('boardEdit', { id: boardId });
		} else {
			snippet = await getSocket().request('boardPlay', { id: boardId });
		}

		this.load(snippet);
	}
}

export const boardState = Board.state;
