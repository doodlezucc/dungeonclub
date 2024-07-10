import { sveltekit } from '@sveltejs/kit/vite';
import { searchForWorkspaceRoot } from 'vite';
import { defineConfig } from 'vitest/config';
import { webSocketServer } from './src/lib/logic/server/ws-server/plugin';

export default defineConfig({
	plugins: [
		sveltekit(),
		webSocketServer({
			handledPath: '/websocket'
		})
	],
	server: {
		fs: {
			allow: [searchForWorkspaceRoot(process.cwd()), '/packages/component-library']
		}
	},
	test: {
		include: ['src/**/*.{test,spec}.{js,ts}']
	}
});
