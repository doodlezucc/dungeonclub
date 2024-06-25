import mongoose from 'mongoose';

export function reloadModels() {}

export function model<T extends mongoose.Schema>(name: string, schema: T) {
	if (mongoose.models[name]) {
		console.log('deleting old model for ' + name);
		delete mongoose.models[name];
	}

	return mongoose.model<T>(name, schema);
}
