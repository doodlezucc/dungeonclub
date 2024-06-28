import { RectSchema, type IRect } from '$lib/net/compounds';
import { Schema } from 'mongoose';
import { TokenSchema, type IToken } from './token';
import {
	AssetType,
	modelWithHierarchy,
	type Asset,
	type DocumentArray,
	type Hydrated
} from './util';

export interface IBoardGrid {
	bounds: IRect;
	cellsPerRow: number;
}

export const BoardGridSchema = new Schema<IBoardGrid>(
	{
		bounds: { type: RectSchema, required: true },
		cellsPerRow: { type: Number, required: true }
	},
	{ _id: false }
);

export interface IBoard {
	background: Asset;
	grid: IBoardGrid;

	tokens: IToken[];
}

export const BoardSchema = new Schema<IBoard>({
	background: { type: AssetType, required: true },
	grid: {
		type: BoardGridSchema,
		default: {
			cellsPerRow: 20,
			bounds: {
				top: 0,
				bottom: 0,
				left: 0,
				right: 0
			}
		}
	},
	tokens: [TokenSchema]
});

export type HydratedBoard = Hydrated<
	IBoard,
	{
		tokens: DocumentArray<IToken>;
	}
>;

export const Board = modelWithHierarchy<HydratedBoard>('Board', BoardSchema);
