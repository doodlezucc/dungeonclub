import { PositionSchema, type IPosition } from '$lib/net/compounds';
import { Schema, Types } from 'mongoose';
import { model } from './util';

export interface IToken {
	definition: Types.ObjectId;
	label: string;
	position: IPosition;
}

export const TokenSchema = new Schema<IToken>({
	definition: { type: Schema.Types.ObjectId, ref: 'TokenDefinition' },
	label: { type: String, default: '' },
	position: { type: PositionSchema, required: true }
});

export const Token = model('Token', TokenSchema);
