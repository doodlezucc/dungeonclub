import type { Asset } from '@prisma/client';
import * as fs from 'fs/promises';
import * as mime from 'mime-types';
import { prisma } from './server';
import { generateUniqueString } from './util/generate-string';

export class AssetManager {
	readonly rootDirFromFrontend: string = '/user-media';
	readonly rootDirFromBackend: string = `./static${this.rootDirFromFrontend}`;

	constructor() {
		this.createStaticDirectory();
	}

	private async createStaticDirectory() {
		await fs.mkdir(this.rootDirFromBackend, { recursive: true });
	}

	async getPathToAsset(assetId: string, { accessibleByFrontend = false }) {
		const asset = await prisma.asset.findFirstOrThrow({
			where: {
				id: assetId
			}
		});

		return this.getPathToFile(asset.path, accessibleByFrontend);
	}

	private getPathToFile(fileName: string, accessibleByFrontend = false) {
		const root = accessibleByFrontend ? this.rootDirFromFrontend : this.rootDirFromBackend;

		return `${root}/${fileName}`;
	}

	async uploadAsset(request: Request): Promise<Asset> {
		const contentType = request.headers.get('Content-Type');

		if (!contentType) {
			throw 'Asset upload failed because Content-Type header is not set';
		}

		const fileExtension = mime.extension(contentType);
		if (!fileExtension) {
			throw 'Asset upload failed because MIME type could not be recognized';
		}

		const fileName = await generateUniqueString({
			length: 8,
			map: (id) => `${id}.${fileExtension}`,
			doesExist: async (fileName) => {
				try {
					const pathToAsset = this.getPathToFile(fileName);
					await fs.access(pathToAsset);
					return true;
				} catch {
					return false;
				}
			}
		});

		const buffer = await request.arrayBuffer();

		const systemPath = this.getPathToFile(fileName);
		await fs.writeFile(systemPath, new Uint8Array(buffer));

		console.log('created asset ' + fileName);

		return await prisma.asset.create({
			data: {
				mimeType: contentType,
				path: fileName
			}
		});
	}

	async disposeAsset(asset: Asset) {
		const filePath = this.getPathToFile(asset.path);
		await fs.unlink(filePath);
	}

	async disposeAssetsInBatch(assets: Asset[]) {
		await Promise.allSettled(assets.map((asset) => this.disposeAsset(asset)));
	}
}
