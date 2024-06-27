import { ClientSocket } from '$lib/client/socket';
import { writable } from 'svelte/store';

export const socket = writable<ClientSocket>(undefined);
