import { error, fail } from '@sveltejs/kit';
import { prisma } from './server';

export async function authorizedEndpoint(
	request: Request,
	requirement: (accountId: string) => Response | Promise<Response>
): Promise<Response> {
	const headers = request.headers;
	const authHeader = headers.get('Authorization');

	const bearerPrefix = 'Bearer ';

	if (!authHeader || !authHeader.startsWith(bearerPrefix)) {
		throw error(401);
	}

	const tokenFromHeader = authHeader.substring(bearerPrefix.length);

	const validToken = await prisma.accessToken.findFirst({
		where: {
			id: tokenFromHeader
		}
	});

	if (!validToken) {
		throw error(403);
	}

	try {
		return await requirement(validToken.accountId);
	} catch (err) {
		if (err && typeof err === 'object' && 'code' in err) {
			const errorCode = `${err.code}`;

			switch (errorCode) {
				case '2025':
					throw error(404, `${err}`);
			}
		}

		throw fail(500, { error: err });
	}
}
