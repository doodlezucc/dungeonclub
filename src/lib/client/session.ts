import type { IBoard, ICampaign } from '$lib/db/schemas';

export class Session {
	campaign: ICampaign;

	visibleBoard?: IBoard;

	constructor(campaign: ICampaign) {
		this.campaign = campaign;
	}
}
