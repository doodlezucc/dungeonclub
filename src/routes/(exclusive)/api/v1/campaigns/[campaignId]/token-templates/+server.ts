import { error, json } from '@sveltejs/kit';
import { prisma } from 'server/prisma.js';
import { authorizedEndpoint } from 'server/rest.js';
import { server } from 'server/server.js';
import { SelectTokenTemplate } from 'shared';

export const POST = ({ params: { campaignId }, request }) =>
	authorizedEndpoint(request, async (accountHash) => {
		const campaign = await prisma.campaign.findUnique({
			where: { id: campaignId }
		});

		if (campaign?.ownerEmail !== accountHash) {
			throw error(403);
		}

		const asset = await server.assetManager.uploadAsset(campaignId, request);

		const tokenTemplate = await prisma.tokenTemplate.create({
			data: {
				campaignId: campaignId,
				avatarId: asset.id,
				name: 'Token'
			},
			select: SelectTokenTemplate
		});

		return json(tokenTemplate);
	});
