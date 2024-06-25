import { Schema } from 'mongoose';

export interface IPosition {
	x: number;
	y: number;
}

export const PositionSchema = new Schema<IPosition>(
	{
		x: { type: Number, required: true },
		y: { type: Number, required: true }
	},
	{ _id: false }
);
