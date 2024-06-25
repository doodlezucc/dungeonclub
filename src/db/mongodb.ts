import { MONGODB_URL } from '$env/static/private';
import mongoose from 'mongoose';
import { Account } from './schemas/account';
import { Campaign } from './schemas/campaign';
import type { IPlayer } from './schemas/player';
import type { IScene } from './schemas/scene';
import type { IToken } from './schemas/token';
import { PlayerTokenDefinition } from './schemas/token-definition';

export async function connect() {
	await mongoose.connect(MONGODB_URL);
	console.log('Connected to database');

	const account = await Account.findOne();

	const result = await Campaign.create({
		owner: account!._id,
		id: 'mycampaign',
		players: [
			{
				name: 'Jojo'
			} as IPlayer
		],
		scenes: [
			{
				background: 'some-img.png'
			} as IScene
		]
	});

	const player1TokenDef = PlayerTokenDefinition.hydrate(result.players[0].tokenDefinition);

	await result.updateOne({
		$push: {
			'scenes.0.tokens': {
				definition: player1TokenDef._id,
				position: {
					x: 0.5,
					y: 1.5
				}
			} as IToken
		}
	});

	console.log(result);
}

export async function disconnect() {
	console.log('Disconnecting from database');
	await mongoose.disconnect();
}
