import type { AllMessages, IForward, IResponse } from '$lib/net';
import {
	MessageCodec,
	type AnyMessage,
	type AnyResponseMessage,
	type AnySendMessage,
	type ResponseMessage,
	type SendMessage
} from './codec';
import type { Payload, Response, ResponseObject } from './handling';

type ChannelCallback<S, T extends keyof S> = (response: Response<S, T>) => void;
type ChannelCallbackMap<S> = Map<number, ChannelCallback<S, keyof S>>;

export abstract class MessageSocket<HANDLED, SENT> {
	private readonly activeChannelCallbacks: ChannelCallbackMap<SENT> = new Map();

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
		return new Promise((resolve) => {
			const channel = this.findUnusedChannel();

			this.activeChannelCallbacks.set(channel, (response) =>
				resolve(response as Response<SENT, T>)
			);

			this.sendMessage({
				name,
				channel,
				payload
			} as AnySendMessage);
		});
	}

	private handleResponse(response: ResponseMessage<SENT, keyof SENT>) {
		const { channel, response: payload } = response;

		const triggerCallback = this.activeChannelCallbacks.get(channel);

		if (triggerCallback) {
			this.activeChannelCallbacks.delete(channel);

			triggerCallback(payload);
		} else {
			console.error(`No callback registered for response channel ${channel}`);
		}
	}

	private async handleMessage(message: SendMessage<HANDLED, keyof HANDLED>) {
		const { name, payload, channel } = message;

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
				name,
				channel,
				response: responsePayload
			} as AnyResponseMessage);
		}
	}

	private async handleIncomingMessage(
		incoming: ResponseMessage<SENT, keyof SENT> | SendMessage<HANDLED, keyof HANDLED>
	) {
		if ('response' in incoming) {
			this.handleResponse(incoming);
		} else {
			return this.handleMessage(incoming);
		}
	}

	public send(name: keyof AllMessages, payload: Payload<AllMessages, keyof AllMessages>) {
		this.sendMessage({
			name,
			payload
		});
	}

	private sendMessage(message: AnyMessage) {
		const encodedMessage = MessageCodec.encode(message);
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
