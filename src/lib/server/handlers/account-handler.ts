import { SelectAccount, type AccountMessageCategory } from '$lib/net';
import { prisma } from '../server';
import type { CategoryHandler } from '../socket';

export const accountHandler: CategoryHandler<AccountMessageCategory> = {
	handleLogin: async ({ email, password }, { dispatcher }) => {
		if (dispatcher.isLoggedIn) {
			throw 'Already logged in';
		}

		const account = await prisma.account.findFirstOrThrow({
			where: {
				email: email,
				password: password
			},
			select: SelectAccount
		});

		const tokenInfo =
			account.tokenInfo ??
			(await prisma.accessToken.create({
				data: {
					accountId: account.id
				}
			}));

		dispatcher.onLogIn(account.id);

		return {
			accessToken: tokenInfo.id,
			id: account.id,
			campaigns: account.campaigns
		};
	},

	handleAccountCreate: async ({ email, password }, { dispatcher }) => {
		if (await prisma.account.findFirst({ where: { email: email } })) {
			throw 'An account with this email address already exists';
		}

		const account = await prisma.account.create({
			data: {
				email,
				password
			},
			select: SelectAccount
		});

		const accessToken = await prisma.accessToken.create({
			data: {
				accountId: account.id
			},
			select: {
				id: true
			}
		});

		dispatcher.onLogIn(account.id);

		console.log('Created new account');

		return {
			accessToken: accessToken.id,
			campaigns: []
		};
	}
};
