import { type AccountMessageCategory } from 'shared';
import { prisma, server } from '../server';
import type { CategoryHandler } from '../socket';

export const accountHandler: CategoryHandler<AccountMessageCategory> = {
	handleLogin: async ({ email, password }, { dispatcher }) => {
		if (dispatcher.isLoggedIn) {
			throw 'Already logged in';
		}

		const account = await server.accountManager.findAccountWithCredentials(email, password);

		const tokenInfo =
			account.tokenInfo ??
			(await prisma.accessToken.create({
				data: {
					accountEmail: account.emailHash
				}
			}));

		dispatcher.onLogIn(account.emailHash);

		return {
			accessToken: tokenInfo.id,
			campaigns: account.campaigns
		};
	},

	handleAccountCreate: async ({ email, password }, { dispatcher }) => {
		const account = await server.accountManager.storeNewAccount(email, password);

		const accessToken = await prisma.accessToken.create({
			data: {
				accountEmail: account.emailHash
			},
			select: {
				id: true
			}
		});

		dispatcher.onLogIn(account.emailHash);

		console.log('Created new account');

		return {
			accessToken: accessToken.id,
			campaigns: []
		};
	}
};
