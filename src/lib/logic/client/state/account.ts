import type { AccountSnippet } from 'shared';
import { getSocket } from '../communication/socket'; // Avoid ../communication/index.ts to prevent cyclic dependency in ../communication/rest.ts
import { WithState } from './with-state';

export class Account extends WithState<AccountSnippet> {
	static readonly instance = new Account();
	static readonly state = this.instance.state;

	static async logIn(emailAddress: string, password: string) {
		const response = await getSocket().request('login', {
			email: emailAddress,
			password: password
		});

		this.instance.set(response);
	}

	static async register(emailAddress: string, password: string) {
		const response = await getSocket().request('accountCreate', {
			email: emailAddress,
			password: password
		});

		this.instance.set(response);
	}
}

export const accountState = Account.state;
