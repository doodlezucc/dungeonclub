import { authorizedEndpoint } from '$lib/server/rest.js';
import { json } from '@sveltejs/kit';

export const GET = ({ request, params }) =>
	authorizedEndpoint(request, () => {
		console.log('i SHOULD check the account first, but whatever');

		return json({
			message: 'yeah, go right ahead',
			params
		});
	});
