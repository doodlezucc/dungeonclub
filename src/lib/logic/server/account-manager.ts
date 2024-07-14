import type { Crypt } from '@prisma/client';
import { SelectAccount } from 'shared';
import { ExpiringCodeManager } from './expiring-code-manager';
import { prisma, server } from './server';
import { TEMPLATE_ACTIVATE_ACCOUNT } from './services/mail/templates';
import { encryptString, hashEmail, matchAgainstCrypt } from './util/encryption';

interface AccountActivationInfo {
	newAccountEmailHash: string;
	newAccountPasswordCrypt: Crypt;
}

interface PasswordResetInfo {
	accountHash: string;
	newPasswordCrypt: Crypt;
}

export class AccountManager {
	readonly accountActivationCodes = new ExpiringCodeManager<AccountActivationInfo>();
	readonly passwordResetCodes = new ExpiringCodeManager<PasswordResetInfo>();

	async doesAccountExist(rawEmail: string) {
		const emailHash = hashEmail(rawEmail);

		const accountProperties = await prisma.account.findFirst({
			where: { emailHash: emailHash }
		});

		return accountProperties !== null;
	}

	async findAccountWithCredentials(rawEmail: string, rawPassword: string) {
		const emailHash = hashEmail(rawEmail);

		const { encryptedPassword } = await prisma.account.findFirstOrThrow({
			where: { emailHash: emailHash },
			select: { encryptedPassword: true }
		});

		const isValidPassword = await matchAgainstCrypt(rawPassword, encryptedPassword);

		if (!isValidPassword) {
			throw 'Password incorrect';
		}

		return await prisma.account.findFirstOrThrow({
			where: { emailHash: emailHash },
			select: SelectAccount
		});
	}

	async prepareUnverifiedAccount(rawEmail: string, rawPassword: string) {
		const emailHash = hashEmail(rawEmail);

		const accountProperties = await prisma.account.findFirst({
			where: { emailHash: emailHash }
		});

		if (accountProperties !== null) {
			throw 'An account with this email address already exists';
		}

		const passwordCrypt = await encryptString(rawPassword);

		const code = await this.accountActivationCodes.registerNewCode(
			{
				newAccountEmailHash: emailHash,
				newAccountPasswordCrypt: passwordCrypt
			},
			{
				onResolve: async () => {
					await this.storeNewAccount(emailHash, passwordCrypt);
				}
			}
		);

		await server.mailService.sendTemplateMail({
			recipient: rawEmail,
			template: TEMPLATE_ACTIVATE_ACCOUNT,
			params: {
				activationCode: code,
				activationUrl: `http://localhost:5173/activate?code=${code}`
			}
		});
	}

	private async storeNewAccount(emailHash: string, passwordCrypt: Crypt) {
		const accountProperties = await prisma.account.findFirst({
			where: { emailHash: emailHash }
		});

		if (accountProperties !== null) {
			throw 'An account with this email address already exists';
		}

		const account = await prisma.account.create({
			data: {
				emailHash: emailHash,
				encryptedPassword: {
					create: passwordCrypt
				}
			}
		});

		const accessToken = await prisma.accessToken.create({
			data: {
				accountEmail: account.emailHash
			},
			select: {
				id: true
			}
		});

		console.log('Created new account');

		return {
			accessToken: accessToken.id,
			campaigns: []
		};
	}
}
