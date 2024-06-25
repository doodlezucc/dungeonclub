import { Schema, Types } from 'mongoose';
import { PlayerSchema, type IPlayer } from './player';
import { SceneSchema, type IScene } from './scene';
import { CustomTokenDefinitionSchema, type ICustomTokenDefinition } from './token-definition';
import { model } from './util/model-reloading';

export interface ICampaign {
	owner: Types.ObjectId;
	id: string;
	name: string;

	players: IPlayer[];
	customTokens: ICustomTokenDefinition[];

	scenes: IScene[];
	activeScene: Types.ObjectId;
}

export const CampaignSchema = new Schema<ICampaign>({
	owner: { type: Schema.Types.ObjectId, ref: 'Account', required: true },
	id: { type: String, required: true },
	name: { type: String, default: 'Untitled Campaign' },
	players: [PlayerSchema],
	customTokens: [CustomTokenDefinitionSchema],
	scenes: [SceneSchema],
	activeScene: { type: Schema.Types.ObjectId, ref: 'Scene' }
});

export const Campaign = model('Campaign', CampaignSchema);
