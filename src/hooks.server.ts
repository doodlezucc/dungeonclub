import type { Handle } from '@sveltejs/kit';
import { server } from 'server/server';
import { setupWebsocketServer } from 'server/ws-server';

export const handle = (async ({ event, resolve }) => {
	setupWebsocketServer();

	const response = await resolve(event, {
		filterSerializedResponseHeaders: (name) => name === 'Content-Type'
	});
	return response;
}) satisfies Handle;

await server.start();
