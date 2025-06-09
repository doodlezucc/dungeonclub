import type { Prisma } from '@prisma/client';

export const SelectAsset = {
	id: true,
	mimeType: true,
	path: true
} satisfies Prisma.AssetSelect;
export type AssetSnippet = Prisma.AssetGetPayload<{
	select: typeof SelectAsset;
}>;

export const SelectTokenPreset = {
	id: true,
	avatarId: true,
	name: true,
	size: true,
	initiativeModifier: true
} satisfies Prisma.TokenPresetSelect;
export type TokenPresetSnippet = Prisma.TokenPresetGetPayload<{
	select: typeof SelectTokenPreset;
}>;

export const SelectPlayerCharacter = {
	id: true,
	tokenPreset: {
		select: SelectTokenPreset
	}
} satisfies Prisma.PlayerCharacterSelect;
export type PlayerCharacterSnippet = Prisma.PlayerCharacterGetPayload<{
	select: typeof SelectPlayerCharacter;
}>;

export const SelectInitiativeOrder = {
	entries: {
		select: {
			token: {
				select: {
					id: true,
					initiativeModifier: true
				}
			},
			roll: true
		}
	}
} satisfies Prisma.InitiativeOrderSelect;
export type InitiativeOrderSnippet = Prisma.InitiativeOrderGetPayload<{
	select: typeof SelectInitiativeOrder;
}>;

export const SelectToken = {
	id: true,
	invisible: true,
	conditions: true,
	name: true,
	avatarId: true,
	x: true,
	y: true,
	size: true,
	initiativeModifier: true
} satisfies Prisma.TokenSelect;
export type TokenSnippet = Prisma.TokenGetPayload<{ select: typeof SelectToken }>;

export type TokenProperties = Omit<
	Prisma.TokenPresetGetPayload<null>,
	'id' | 'campaignId' | 'avatar'
>;
export type OverridableTokenProperty = keyof TokenProperties;

export const SelectTokenProperties = {
	name: true,
	size: true,
	avatarId: true,
	initiativeModifier: true
} satisfies Record<
	OverridableTokenProperty,
	true
> satisfies Prisma.TokenSelect satisfies Prisma.TokenPresetSelect;

export const SelectBoardPreview = {
	id: true,
	name: true,
	mapImageId: true
} satisfies Prisma.BoardSelect;
export type BoardPreviewSnippet = Prisma.BoardGetPayload<{ select: typeof SelectBoardPreview }>;

export const SelectBoard = {
	...SelectBoardPreview,
	gridCellsPerRow: true,
	gridPaddingTop: true,
	gridPaddingBottom: true,
	gridPaddingLeft: true,
	gridPaddingRight: true,
	gridType: true,
	initiativeOrder: {
		include: SelectInitiativeOrder
	},
	tokens: {
		select: SelectToken
	}
} satisfies Prisma.BoardSelect;
export type BoardSnippet = Prisma.BoardGetPayload<{ select: typeof SelectBoard }>;

export const SelectCampaignCard = {
	id: true,
	name: true,
	createdAt: true,
	playerCharacters: {
		select: SelectPlayerCharacter
	}
} satisfies Prisma.CampaignSelect;
export type CampaignCardSnippet = Prisma.CampaignGetPayload<{ select: typeof SelectCampaignCard }>;

export const SelectCampaign = {
	...SelectCampaignCard,
	audioEffectInside: true,
	audioSfxCrowd: true,
	audioSfxWeather: true,
	boards: {
		select: SelectBoardPreview
	},
	boardIdsOrdered: true,
	selectedBoardId: true,
	tokenPresets: {
		select: SelectTokenPreset
	},
	assets: {
		select: SelectAsset
	}
} satisfies Prisma.CampaignSelect;
export type CampaignSnippet = Prisma.CampaignGetPayload<{ select: typeof SelectCampaign }> & {
	selectedBoard?: BoardSnippet;
};

export const SelectAccount = {
	emailHash: true,
	tokenInfo: {
		select: { id: true }
	},
	campaigns: {
		select: SelectCampaignCard
	},
	campaignIdsOrdered: true
} satisfies Prisma.AccountSelect;
export type AccountSnippet = {
	accessToken: string;
	campaigns: CampaignCardSnippet[];
};
