import type {
	AssetSnippet,
	CampaignCardSnippet,
	CampaignSnippet,
	TokenPresetSnippet
} from '../snippets';
import type { DefinePrivateRequest, DefineServerBroadcast, UUID } from './messages';

export interface CampaignMessageCategory {
	campaignCreate: DefinePrivateRequest<
		{
			name: string;
		},
		CampaignSnippet
	>;

	campaignDelete: DefinePrivateRequest<
		{
			id: string;
		},
		void
	>;

	campaignReorder: DefinePrivateRequest<
		{
			campaignIds: string[];
		},
		void
	>;

	campaignEdit: DefinePrivateRequest<Omit<CampaignCardSnippet, 'createdAt'>, CampaignCardSnippet>;

	campaignHost: DefinePrivateRequest<
		{
			id: UUID;
		},
		CampaignSnippet
	>;

	campaignJoin: DefinePrivateRequest<
		{
			id: UUID;
		},
		CampaignSnippet
	>;

	tokenPresetDelete: DefinePrivateRequest<
		{
			tokenPresetId: UUID;
		},
		void
	>;

	tokenPresetRestore: DefinePrivateRequest<
		{
			tokenPresetId: UUID;
		},
		void
	>;

	tokenPresetCreate: DefineServerBroadcast<{
		tokenPreset: TokenPresetSnippet;
	}>;

	assetCreate: DefineServerBroadcast<{
		asset: AssetSnippet;
	}>;
}
