import { json } from '@sveltejs/kit';
import { error } from 'console';
import { authorizedEndpoint } from 'server/rest.js';
import { prisma } from 'server/server.js';

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
