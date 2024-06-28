import { Schema, Types, type HydratedDocument } from 'mongoose';
import { BoardSchema, type IBoard } from './board';
import { PlayerSchema, type IPlayer } from './player';
import { CustomTokenDefinitionSchema, type ICustomTokenDefinition } from './token-definition';
import { modelWithHierarchy, type DocumentArray, type Timestamped } from './util';

export interface ICampaign extends Timestamped {
	id: string;
	name: string;

	players: IPlayer[];
	customTokens: ICustomTokenDefinition[];

	boards: IBoard[];
	activeBoard: Types.ObjectId;
}

export const CampaignSchema = new Schema<ICampaign>(
	{
		id: { type: String, required: true },
		name: { type: String, default: 'Untitled Campaign' },
		players: [PlayerSchema],
		customTokens: [CustomTokenDefinitionSchema],
		boards: [BoardSchema],
		activeBoard: { type: Schema.Types.ObjectId, ref: 'Board' }
	},
	{ timestamps: true }
);

export type HydratedCampaign = HydratedDocument<
	ICampaign,
	{
		players: DocumentArray<IPlayer>;
		customTokens: DocumentArray<ICustomTokenDefinition>;
		boards: DocumentArray<IBoard>;
	}
>;

export const Campaign = modelWithHierarchy<HydratedCampaign>('Campaign', CampaignSchema);
