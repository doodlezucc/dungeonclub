import { historyOf, type HistoryStore } from '$lib/packages/undo-redo/history';
import { writable } from 'svelte/store';

export const focusedHistory = writable<HistoryStore | null>(null);

export const tokenTemplatesHistory = historyOf({});
