import type { Asset } from '@prisma/client';
import { prisma } from './server';

import { mkdir, writeFile } from 'fs/promises';

export class AssetManager {
	readonly rootDirFromFrontend: string = '/user-media';
	readonly rootDirFromBackend: string = `./static${this.rootDirFromFrontend}`;

	constructor() {
		this.createStaticDirectory();
	}

	private async createStaticDirectory() {
		await mkdir(this.rootDirFromBackend, { recursive: true });
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
		const buffer = await request.arrayBuffer();

		const fileName = 'myasset.png';

		const systemPath = this.getPathToFile(fileName);
		await writeFile(systemPath, new Uint8Array(buffer));

		console.log('created asset ' + fileName);

		return await prisma.asset.create({
			data: {
				fileType: 'IMAGE',
				path: fileName
			}
		});
	}
}
