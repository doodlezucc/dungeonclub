import { Schema, Types, type HydratedDocument } from 'mongoose';
import { PlayerSchema, type IPlayer } from './player';
import { SceneSchema, type IScene } from './scene';
import { CustomTokenDefinitionSchema, type ICustomTokenDefinition } from './token-definition';
import { modelWithHierarchy, type DocumentArray, type Timestamped } from './util';

export interface ICampaign extends Timestamped {
	id: string;
	name: string;

	players: IPlayer[];
	customTokens: ICustomTokenDefinition[];

	scenes: IScene[];
	activeScene: Types.ObjectId;
}

export const CampaignSchema = new Schema<ICampaign>({
	id: { type: String, required: true },
	name: { type: String, default: 'Untitled Campaign' },
	players: [PlayerSchema],
	customTokens: [CustomTokenDefinitionSchema],
	scenes: [SceneSchema],
	activeScene: { type: Schema.Types.ObjectId, ref: 'Scene' }
});

export type HydratedCampaign = HydratedDocument<
	ICampaign,
	{
		players: DocumentArray<IPlayer>;
		customTokens: DocumentArray<ICustomTokenDefinition>;
		scenes: DocumentArray<IScene>;
	}
>;

export const Campaign = modelWithHierarchy<HydratedCampaign>('Campaign', CampaignSchema);
