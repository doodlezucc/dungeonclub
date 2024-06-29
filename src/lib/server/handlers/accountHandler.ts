import type { AccountMessageCategory } from '$lib/net';
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
			include: {
				campaigns: {
					select: {
						id: true,
						name: true,
						createdAt: true,
						playerCharacters: {
							include: {
								tokenTemplate: true
							}
						}
					}
				}
			}
		});

		dispatcher.onLogIn(account);

		return {
			account: {
				email,
				campaigns: account.campaigns
			}
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
			}
		});

		console.log('Created account', account);
		dispatcher.onLogIn(account);

		return {
			account: {
				email,
				campaigns: []
			}
		};
	}
};
