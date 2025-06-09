import { SelectTokenPreset } from '$lib/net';
import { prisma } from '$lib/server/prisma.js';
import { campaignEndpoint } from '$lib/server/rest.js';
import { server } from '$lib/server/server.js';
import { json } from '@sveltejs/kit';

export const POST = ({ params: { campaignId }, request }) =>
	campaignEndpoint(request, campaignId, async () => {
		const asset = await server.assetManager.uploadAsset(campaignId, request);

		const tokenPreset = await prisma.tokenPreset.create({
			data: {
				campaignId: campaignId,
				avatarId: asset.id,
				name: 'Token'
			},
			select: SelectTokenPreset
		});

		server.sessionManager.findSession(campaignId)?.broadcastMessage('tokenPresetCreate', {
			tokenPreset: tokenPreset
		});

		return json(tokenPreset);
	});
