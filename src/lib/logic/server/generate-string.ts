const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const lowercase = 'abcdefghijklmnopqrstuvwxyz';
const digits = '0123456789';

const defaultAllowedCharacters = [uppercase, lowercase, digits].join('');

export interface GenerateIDOptions {
	/**
	 * Defaults to:
	 *  - 26 uppercase letters (latin alphabet)
	 *  - 26 lowercase letters (latin alphabet)
	 *  - digits 0 through 9
	 * */
	allowedCharacters?: string;

	length: number;
}

export interface GenerateUniqueStringOptions<T> extends GenerateIDOptions {
	map?: (id: string) => T;
	doesExist: (suggestion: T) => Promise<boolean>;
}

export async function generateUniqueString<T = string>(
	options: GenerateUniqueStringOptions<T>
): Promise<T> {
	const { map, doesExist } = options;

	for (let i = 0; i < 100; i++) {
		const id = generateID(options);
		const mapped = map ? map(id) : (id as T);

		const alreadyExists = await doesExist(mapped);

		if (!alreadyExists) {
			return mapped;
		}
	}

	throw 'No unique IDs found after 100 tries';
}

function generateID(options: GenerateIDOptions): string {
	const { length } = options;

	const pool = options.allowedCharacters ?? defaultAllowedCharacters;

	function randomCharacter() {
		return pool[Math.floor(Math.random() * pool.length)];
	}

	let result = '';

	for (let i = 0; i < length; i++) {
		result += randomCharacter();
	}

	return result;
}
