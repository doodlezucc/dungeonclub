class BidirectionalMap<K, V> {
	private readonly forward = new Map<K, V>();
	private readonly inverse = new Map<V, K>();

	private link(leftSide: K, rightSide: V) {
		this.forward.set(leftSide, rightSide);
		this.inverse.set(rightSide, leftSide);
	}

	set(key: K, value: V) {
		this.link(key, value);
	}

	setInverse(key: V, value: K) {
		this.link(value, key);
	}

	get(key: K) {
		return this.forward.get(key);
	}

	getInverse(key: V) {
		return this.inverse.get(key);
	}
}

export interface Reference {
	resolve(): string;
}

export interface WritableReference extends Reference {
	set(value: string): void;
	clear(): void;
}

export class ReferenceLookup {
	private readonly persistentToAliveIdMap = new BidirectionalMap<number, string | undefined>();
	private uniqueIdCounter = 0;

	private resolveReference(persistentId: number) {
		const aliveId = this.persistentToAliveIdMap.get(persistentId);

		if (!aliveId) {
			throw 'Reference is unset';
		}

		return aliveId;
	}

	private persistentReference(persistentId: number): WritableReference {
		return {
			resolve: () => this.resolveReference(persistentId),
			set: (value) => this.persistentToAliveIdMap.set(persistentId, value),
			clear: () => this.persistentToAliveIdMap.set(persistentId, undefined)
		};
	}

	allocateNewReference(initialValue?: string): WritableReference {
		const persistentId = this.uniqueIdCounter++;

		this.persistentToAliveIdMap.set(persistentId, initialValue);
		return this.persistentReference(persistentId);
	}

	referenceTo(aliveId: string): WritableReference {
		const persistentId = this.persistentToAliveIdMap.getInverse(aliveId);

		if (persistentId !== undefined) {
			// Alive ID is already known
			return this.persistentReference(persistentId);
		} else {
			return this.allocateNewReference(aliveId);
		}
	}
}

const globalReferenceLookup = new ReferenceLookup();

export function referenceTo(aliveId: string) {
	return globalReferenceLookup.referenceTo(aliveId) as Reference;
}

export function writableReferenceTo(aliveId: string) {
	return globalReferenceLookup.referenceTo(aliveId);
}

export function allocateNewReference(initialValue?: string) {
	return globalReferenceLookup.allocateNewReference(initialValue);
}
