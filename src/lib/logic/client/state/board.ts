import { GridSpaces } from '$lib/packages/grid/grid-snapping';
import type { GridSpace } from '$lib/packages/grid/spaces/interface';
import { historyOf } from '$lib/packages/undo-redo/history';
import type { BoardSnippet, GetPayload } from 'shared';
import { derived, type Readable } from 'svelte/store';
import { getSocket } from '../communication';
import { focusedHistory } from './focused-history';
import { WithState } from './with-state';

export class BoardGrid {
	readonly gridSpace: Readable<GridSpace | null>;

	constructor(readonly board: Board) {
		this.gridSpace = derived(board.state, (boardState) => {
			return boardState ? GridSpaces.parse(boardState.gridType) : null;
		});
	}
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
		focusedHistory.set(historyOf(snippet.id));
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

	handleTokenMove({ id, position }: GetPayload<'tokenMove'>) {
		this.put((board) => ({
			...board,
			tokens: board.tokens.map((token) => (token.id === id ? { ...token, ...position } : token))
		}));
	}
}

export const boardState = Board.state;
