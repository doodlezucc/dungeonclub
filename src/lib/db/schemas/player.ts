import { Schema } from 'mongoose';
import { PlayerTokenDefinitionSchema, type IPlayerTokenDefinition } from './token-definition';
import { model } from './util/model-reloading';
import { AssetType, type Asset } from './util/types';

export interface IPlayer {
	avatar?: Asset;
	name: string;
	tokenDefinition: IPlayerTokenDefinition;
}

export const PlayerSchema = new Schema<IPlayer>({
	avatar: { type: AssetType },
	name: { type: String, required: true },
	tokenDefinition: {
		type: PlayerTokenDefinitionSchema,
		default: {
			size: 1
		}
	}
});

export const Player = model('Player', PlayerSchema);
