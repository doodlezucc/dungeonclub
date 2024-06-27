import type { IForward, IResponse } from '$lib/net';
import {
	MessageCodec,
	type AnyMessage,
	type AnyResponseMessage,
	type AnySendMessage,
	type ResponseMessage,
	type SendMessage
} from './codec';
import type { Payload, Response, ResponseObject } from './handling';

type ChannelCallback<S, T extends keyof S> = (response: ResponseMessage<S, T>) => void;
type ChannelCallbackMap<S> = Map<number, ChannelCallback<S, keyof S>>;

interface Props {
	unready: boolean;
}
const defaultProps: Props = {
	unready: false
};

export abstract class MessageSocket<HANDLED, SENT> {
	private readonly activeChannelCallbacks: ChannelCallbackMap<SENT> = new Map();

	private readonly readyEvent: Promise<void>;
	private resolveReadyState?: () => void;
	private isReady: boolean = false;

	constructor(props?: Partial<Props>) {
		const { unready } = {
			...defaultProps,
			...props
		};

		if (unready) {
			this.readyEvent = new Promise<void>((resolve) => {
				this.resolveReadyState = resolve;
			});
		} else {
			this.isReady = true;
			this.readyEvent = Promise.resolve();
		}
	}

	protected markAsReady() {
		this.isReady = true;
		if (this.resolveReadyState) {
			this.resolveReadyState();
		}
	}

	private findUnusedChannel(): number {
		const countActiveChannels = this.activeChannelCallbacks.size;

		for (let channel = 0; channel < countActiveChannels; channel++) {
			if (!this.activeChannelCallbacks.has(channel)) {
				return channel;
			}
		}

		return countActiveChannels;
	}

	public async request<T extends keyof SENT>(
		name: T,
		payload: Payload<SENT, T>
	): Promise<Response<SENT, T>> {
		return new Promise((resolve, reject) => {
			const channel = this.findUnusedChannel();

			this.activeChannelCallbacks.set(channel, (responseMessage) => {
				const { error, response: payload } = responseMessage;

				if (error || !payload) {
					reject('Request failed: ' + error);
				} else {
					resolve(payload);
				}
			});

			this.sendMessage({
				name,
				channel,
				payload
			} as AnySendMessage);
		});
	}

	private handleResponse(response: ResponseMessage<SENT, keyof SENT>) {
		const { channel } = response;

		const triggerCallback = this.activeChannelCallbacks.get(channel);

		if (triggerCallback) {
			this.activeChannelCallbacks.delete(channel);

			triggerCallback(response);
		} else {
			console.error(`No callback registered for response channel ${channel}`);
		}
	}

	private async handleMessage(message: SendMessage<HANDLED, keyof HANDLED>) {
		const { name, payload, channel } = message;

		try {
			const result = (await this.processMessage(name, payload)) as Response<HANDLED, keyof HANDLED>;

			let responsePayload = result;

			if (result && typeof result === 'object') {
				const multiResponse = responsePayload as IForward<unknown> | IResponse<unknown>;

				if ('forwardedPayload' in multiResponse) {
					const { forwardedPayload } = multiResponse;

					console.log('forward to other players', forwardedPayload);
				}
				if ('response' in multiResponse) {
					responsePayload = multiResponse.response as Response<HANDLED, keyof HANDLED>;
				}
			}

			if (channel !== undefined) {
				// Communication partner wants to receive a response on this channel
				this.sendMessage({
					channel,
					response: responsePayload
				} as AnyResponseMessage);
			}
		} catch (err) {
			console.error('Error while processing message <', name, '>', payload);
			console.error(err);

			if (channel !== undefined) {
				this.sendMessage({
					channel,
					error: `${err}`
				} as AnyResponseMessage);
			}
		}
	}

	private async handleIncomingMessage(
		incoming: ResponseMessage<SENT, keyof SENT> | SendMessage<HANDLED, keyof HANDLED>
	) {
		if ('payload' in incoming) {
			return this.handleMessage(incoming);
		} else {
			this.handleResponse(incoming);
		}
	}

	public send(name: keyof SENT, payload: Payload<SENT, keyof SENT>) {
		this.sendMessage({
			name,
			payload
		} as AnyMessage);
	}

	private async sendMessage(message: AnyMessage) {
		if (!this.isReady) {
			await this.readyEvent;
		}

		const encodedMessage = MessageCodec.encode(message as AnyMessage);
		this.sendOutgoingMessage(encodedMessage);
	}

	public receiveIncomingMessage(encodedMessage: string) {
		const incoming = MessageCodec.decode(encodedMessage);
		this.handleIncomingMessage(
			incoming as ResponseMessage<SENT, keyof SENT> | SendMessage<HANDLED, keyof HANDLED>
		);
	}

	protected abstract processMessage<T extends keyof HANDLED>(
		name: T,
		payload: Payload<HANDLED, T>
	): Promise<ResponseObject<HANDLED, T>>;
	protected abstract sendOutgoingMessage(encodedMessage: string): void;
}
