import { Schema } from 'mongoose';

export interface IRect {
	top: number;
	bottom: number;
	left: number;
	right: number;
}

export const RectSchema = new Schema<IRect>(
	{
		top: { type: Number, required: true },
		bottom: { type: Number, required: true },
		left: { type: Number, required: true },
		right: { type: Number, required: true }
	},
	{ _id: false }
);
