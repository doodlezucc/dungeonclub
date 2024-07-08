export interface BidirectionalAction {
	name: string;
	do(): Promise<void>;
	undo(): Promise<void>;
}
