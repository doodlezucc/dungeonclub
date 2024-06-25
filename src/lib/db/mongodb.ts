import { MONGODB_URL } from '$env/static/private';
import mongoose from 'mongoose';

export async function connect() {
	await mongoose.connect(MONGODB_URL);
	console.log('Connected to database');
}

export async function disconnect() {
	console.log('Disconnecting from database');
	await mongoose.disconnect();
}
