import type { ICampaign, IScene } from '$lib/db/schemas';

export class Session {
	campaign: ICampaign;

	visibleScene?: IScene;

	constructor(campaign: ICampaign) {
		this.campaign = campaign;
	}
}
