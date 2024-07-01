import { readable } from 'svelte/store';
import { account } from '../state';

interface RequestOptions {
	params?: Record<string, string>;
	body?: unknown;
}

export class RestConnection {
	private _accessToken: string | undefined;

	constructor() {
		account.subscribe((account) => {
			if (account) {
				this._accessToken = account.accessToken;
			}
		});
	}

	get accessToken() {
		return this._accessToken;
	}

	private async request(method: string, endpoint: string, options?: RequestOptions) {
		const endpointPath = `/api/v1${endpoint}`;

		let path = endpointPath;

		if (options?.params) {
			path += '?' + new URLSearchParams(options.params).toString();
		}

		const response = await fetch(path, {
			method: method,
			headers: this.accessToken
				? {
						Authorization: 'Bearer ' + this.accessToken
					}
				: undefined,
			credentials: 'include'
		});

		return await response.json();
	}

	get(endpoint: string, options?: RequestOptions) {
		return this.request('GET', endpoint, options);
	}

	post(endpoint: string, options?: RequestOptions) {
		return this.request('POST', endpoint, options);
	}
}

export const rest = readable(new RestConnection());
