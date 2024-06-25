import { Schema, model } from 'mongoose';
import { AssetType, type Asset } from './compounds/types';

export interface ITokenDefinition {
	size: number;
}

export type IPlayerTokenDefinition = ITokenDefinition;

export interface ICustomTokenDefinition extends ITokenDefinition {
	image: Asset;
	name: string;
}

export const PlayerTokenDefinitionSchema = new Schema<IPlayerTokenDefinition>({
	size: { type: Number, required: true }
});

export const CustomTokenDefinitionSchema = new Schema<ICustomTokenDefinition>({
	image: { type: AssetType, required: true },
	name: { type: String, required: true },
	size: { type: Number, required: true }
});

export const PlayerTokenDefinition = model('PlayerTokenDefinition', PlayerTokenDefinitionSchema);
export const CustomTokenDefinition = model('CustomTokenDefinition', CustomTokenDefinitionSchema);
