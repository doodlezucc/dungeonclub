import { SelectAccount } from 'shared';
import { prisma } from './server';
import { encryptString, hashEmail, matchAgainstCrypt } from './util/encryption';

export class AccountManager {
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

	async storeNewAccount(rawEmail: string, rawPassword: string) {
		const emailHash = hashEmail(rawEmail);

		const accountProperties = await prisma.account.findFirst({
			where: { emailHash: emailHash }
		});

		if (accountProperties !== null) {
			throw 'An account with this email address already exists';
		}

		const passwordCrypt = await encryptString(rawPassword);

		return await prisma.account.create({
			data: {
				emailHash: emailHash,
				encryptedPassword: {
					create: passwordCrypt
				}
			}
		});
	}
}
