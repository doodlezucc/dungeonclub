import { Campaign } from '$lib/db/schemas/campaign.js';

export async function load({ params }) {
	const gameID = params.game;

	const campaign = await Campaign.findOne({
		id: gameID
	});

	return {
		campaign: campaign?.toJSON({ flattenObjectIds: true })
	};
}
