import type { Types } from 'mongoose';

export type DocumentArray<T> = Types.DocumentArray<T>;
export type SubDocument<T> = Types.Subdocument<T>;

export type Asset = string;
export const AssetType = String;
