import type { TokenPresetSnippet, TokenProperties, TokenSnippet } from '$lib/net';
import { prisma } from './prisma';
import { server } from './server';

export interface DeletedTokenInfo {
	boardId: string;
	token: TokenSnippet;
}

export interface DeletedTokenPresetInfo {
	tokenPreset: TokenProperties & TokenPresetSnippet;
}

export class SessionGarbage {
	readonly tokens = new DedicatedGarbage<string, DeletedTokenInfo>({
		onPurge: async (markedForDeletion) => {
			const idsMarkedForDeletion = Array.from(markedForDeletion.keys());

			await prisma.token.deleteMany({
				where: {
					id: { in: idsMarkedForDeletion }
				}
			});
		}
	});

	readonly tokenPresets = new DedicatedGarbage<string, DeletedTokenPresetInfo>({
		onPurge: async (markedForDeletion) => {
			const idsMarkedForDeletion = Array.from(markedForDeletion.keys());

			await prisma.tokenPreset.deleteMany({
				where: { id: { in: idsMarkedForDeletion } }
			});

			for (const info of markedForDeletion.values()) {
				const avatarIdOfDeletedPreset = info.tokenPreset.avatarId;

				if (avatarIdOfDeletedPreset !== null) {
					await server.assetManager.deleteIfUnused(avatarIdOfDeletedPreset);
				}
			}
		}
	});

	private get subGarbages() {
		return [this.tokens, this.tokenPresets];
	}

	purge() {
		for (const garbage of this.subGarbages) {
			garbage.purge();
		}
	}
}

export interface DedicatedGarbageProps<K, V> {
	onPurge: (markedForDeletion: Map<K, V>) => Promise<void>;
}

class DedicatedGarbage<K, V> {
	private readonly markedForDeletion = new Map<K, V>();
	private readonly properties: DedicatedGarbageProps<K, V>;

	constructor(properties: DedicatedGarbageProps<K, V>) {
		this.properties = properties;
	}

	keysMarkedForDeletion() {
		return Array.from(this.markedForDeletion.keys());
	}

	isMarkedForDeletion(key: K) {
		return this.markedForDeletion.has(key);
	}

	markForDeletion(key: K, item: V) {
		this.markedForDeletion.set(key, item);
	}

	restore(key: K) {
		const item = this.markedForDeletion.get(key);
		if (item === undefined) {
			throw 'No item with this key is marked for deletion';
		}

		this.markedForDeletion.delete(key);
		return item;
	}

	restoreMany(keys: K[]) {
		const recoveredValidItems: V[] = [];

		for (const key of keys) {
			const item = this.markedForDeletion.get(key);

			if (item !== undefined) {
				this.markedForDeletion.delete(key);
				recoveredValidItems.push(item);
			}
		}

		return recoveredValidItems;
	}

	async purge() {
		if (this.markedForDeletion.size === 0) {
			return;
		}

		const itemsToPurge = new Map(this.markedForDeletion.entries());
		this.markedForDeletion.clear();

		await this.properties.onPurge(itemsToPurge);
	}
}
