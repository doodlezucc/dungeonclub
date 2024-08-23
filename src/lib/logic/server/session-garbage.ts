import type { TokenSnippet } from 'shared';
import { prisma } from './prisma';

type DeletedTokenInfo = {
	boardId: string;
	token: TokenSnippet;
};

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

	private get subGarbages() {
		return [this.tokens];
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
