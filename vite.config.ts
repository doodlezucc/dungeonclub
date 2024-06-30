import { sveltekit } from '@sveltejs/kit/vite';
import { webSocketServer } from 'svelte-ws-server';
import { searchForWorkspaceRoot } from 'vite';
import { defineConfig } from 'vitest/config';

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
