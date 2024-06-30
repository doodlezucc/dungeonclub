import { sveltekit } from '@sveltejs/kit/vite';
import { webSocketServer } from 'svelte-ws-server';
import { defineConfig } from 'vitest/config';

export default defineConfig({
	plugins: [sveltekit(), webSocketServer()],
	test: {
		include: ['src/**/*.{test,spec}.{js,ts}']
	}
});
