import { prisma } from './server';

export class AssetManager {
	readonly rootDirFromFrontend: string = '/user-media';
	readonly rootDirFromBackend: string = `./static${this.rootDirFromFrontend}`;

	async getPathToAsset(assetId: string, { accessibleByFrontend = false }) {
		const asset = await prisma.asset.findFirstOrThrow({
			where: {
				id: assetId
			}
		});

		const root = accessibleByFrontend ? this.rootDirFromFrontend : this.rootDirFromBackend;

		return `${root}/${asset.path}`;
	}

	async uploadAsset(request: Request) {}
}
