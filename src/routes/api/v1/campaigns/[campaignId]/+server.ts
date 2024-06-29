import { authorizedEndpoint } from '$lib/server/rest.js';
import { prisma } from '$lib/server/server.js';
import { json } from '@sveltejs/kit';
import { error } from 'console';

export const GET = ({ request, params: { campaignId } }) =>
	authorizedEndpoint(request, async (accountId) => {
		const campaign = await prisma.campaign.findFirstOrThrow({
			where: {
				id: campaignId
			}
		});

		if (campaign.ownerId !== accountId) {
			throw error(403);
		}

		return json(campaign);
	});
