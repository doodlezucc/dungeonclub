import { type HistoryStore } from 'packages/undo-redo/history';
import { writable } from 'svelte/store';

export const focusedHistory = writable<HistoryStore | null>(null);
