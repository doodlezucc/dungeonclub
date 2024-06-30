import { server } from '$lib/server/server';

import type { ExtendedGlobal } from '$lib/server/web-socket-utils';
import { GlobalThisWSS } from '$lib/server/web-socket-utils';
import type { Handle } from '@sveltejs/kit';

// This can be extracted into a separate file
let wssInitialized = false;
const startupWebsocketServer = () => {
	if (wssInitialized) return;
	const wss = (globalThis as ExtendedGlobal)[GlobalThisWSS];

	if (wss !== undefined) {
		const listeners = wss.listeners('connection');

		// Remove stale listeners registered before a hot restart
		for (let i = 1; i < listeners.length; i++) {
			wss.removeListener('connection', listeners[0] as () => void);
		}
	}

	wssInitialized = true;
};

export const handle = (async ({ event, resolve }) => {
	startupWebsocketServer();

	const response = await resolve(event, {
		filterSerializedResponseHeaders: (name) => name === 'Content-Type'
	});
	return response;
}) satisfies Handle;

await server.start();
