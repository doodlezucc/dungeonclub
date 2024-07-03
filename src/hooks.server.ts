import { server } from '$lib/server/server';
import { setupWebsocketServer } from '$lib/server/ws-server';
import type { Handle } from '@sveltejs/kit';

export const handle = (async ({ event, resolve }) => {
	setupWebsocketServer();

	const response = await resolve(event, {
		filterSerializedResponseHeaders: (name) => name === 'Content-Type'
	});
	return response;
}) satisfies Handle;

await server.start();
