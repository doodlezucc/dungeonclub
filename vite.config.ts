import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';
import { webSocketServer } from './src/lib/server/ws-server/plugin';

export default defineConfig({
	plugins: [
		sveltekit(),
		webSocketServer({
			handledPath: '/websocket'
		})
	],
	server: {
		fs: {
			allow: ['./user-media']
		}
	},
	optimizeDeps: {
		include: [
			'@fortawesome/fontawesome-svg-core',
			'@fortawesome/free-brands-svg-icons',
			'@fortawesome/free-solid-svg-icons',
			'@fortawesome/svelte-fontawesome',
			'lodash/isEqual',
			'svelte-time'
		]
	},
	test: {
		expect: { requireAssertions: true },
		projects: [
			{
				extends: './vite.config.ts',
				test: {
					name: 'client',
					include: ['src/**/*.svelte.{test,spec}.{js,ts}'],
					exclude: ['src/lib/server/**']
				}
			},

			{
				extends: './vite.config.ts',
				test: {
					name: 'server',
					environment: 'node',
					include: ['src/**/*.{test,spec}.{js,ts}'],
					exclude: ['src/**/*.svelte.{test,spec}.{js,ts}']
				}
			}
		]
	}
});
