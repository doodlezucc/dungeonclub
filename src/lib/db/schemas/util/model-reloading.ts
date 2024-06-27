import mongoose from 'mongoose';

export function model<T extends mongoose.Schema>(name: string, schema: T) {
	if (mongoose.models[name]) {
		console.log('deleting old model for ' + name);
		delete mongoose.models[name];
	}

	return mongoose.model<T>(name, schema);
}

export type ISchemaFromHydrated<T extends mongoose.HydratedDocument<unknown, unknown>> =
	T extends mongoose.HydratedDocument<infer ISCHEMA> ? ISCHEMA : never;

export type OverridesFromHydrated<T extends mongoose.HydratedDocument<unknown, unknown>> =
	T extends mongoose.HydratedDocument<unknown, infer OVERRIDES> ? OVERRIDES : never;

export function modelWithHierarchy<U extends mongoose.HydratedDocument<unknown, unknown>>(
	name: string,
	schema: mongoose.Schema<ISchemaFromHydrated<U>>
) {
	if (mongoose.models[name]) {
		console.log('deleting old model for ' + name);
		delete mongoose.models[name];
	}

	return mongoose.model<
		mongoose.Schema<ISchemaFromHydrated<U>>,
		mongoose.Model<ISchemaFromHydrated<U>, unknown, unknown, unknown, OverridesFromHydrated<U>>
	>(name, schema);
}
