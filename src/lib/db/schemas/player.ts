import { Schema, Types } from 'mongoose';
import { PlayerTokenDefinitionSchema, type IPlayerTokenDefinition } from './token-definition';
import { AssetType, model, type Asset } from './util';

export interface IPlayer {
	_id?: Types.ObjectId;
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
