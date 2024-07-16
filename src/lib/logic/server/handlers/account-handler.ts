import { type AccountMessageCategory } from 'shared';
import { prisma, server } from '../server';
import type { CategoryHandler } from '../socket';

export const accountHandler: CategoryHandler<AccountMessageCategory> = {
	handleLogin: async ({ email, password }, { dispatcher }) => {
		if (dispatcher.isLoggedIn) {
			throw 'Already logged in';
		}

		const account = await server.accountManager.login(email, password);

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

	handleAccountCreate: async ({ email, password }) => {
		await server.accountManager.prepareUnverifiedAccount(email, password);
		return true;
	},

	handleAccountResetPassword: async ({ email, password }) => {
		await server.accountManager.preparePasswordReset(email, password);
		return true;
	}
};
