import { Server } from '$lib/server/server';

export const server = new Server();
await server.start();
