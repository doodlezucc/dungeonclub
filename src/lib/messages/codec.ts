import type { Payload, Response } from './handling';
import type { MessageName } from './messages';

export type SendMessage<T extends MessageName> = {
	name: T;
	payload: Payload<T>;

	/** If passed, this message is expected to receive a response marked with an identical channel value. */
	channel?: number;
};

export type ResponseMessage<T extends MessageName> = {
	response: Response<T>;
	channel: number;
};

export type AnyMessage = SendMessage<MessageName> | ResponseMessage<MessageName>;

export class MessageCodec {
	static encode(message: AnyMessage): string {
		return JSON.stringify(message);
	}

	static decode(encodedMessage: string): AnyMessage {
		return JSON.parse(encodedMessage);
	}
}
