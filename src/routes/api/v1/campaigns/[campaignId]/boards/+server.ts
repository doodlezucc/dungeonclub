import { json } from '@sveltejs/kit';

export async function POST({ params }) {
	return json(params);
}
