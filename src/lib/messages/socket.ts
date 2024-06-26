import { MessageCodec, type AnyMessage, type ResponseMessage } from './codec';
import type { Payload, Response } from './handling';

type ChannelCallback<S, T extends keyof S> = (response: Response<S, T>) => void;
type ChannelCallbackMap<S> = Map<number, ChannelCallback<S, keyof S>>;

export abstract class MessageSocket<HANDLED, SENT> {
	private readonly activeChannelCallbacks: ChannelCallbackMap<HANDLED> = new Map();

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
			});
		});
	}

	private handleResponse(response: ResponseMessage<keyof HANDLED>) {
		const { channel, response: payload } = response;

		const triggerCallback = this.activeChannelCallbacks.get(channel);

		if (triggerCallback) {
			this.activeChannelCallbacks.delete(channel);

			triggerCallback(payload);
		} else {
			console.error(`No callback registered for response channel ${channel}`);
		}
	}

	private async handleIncomingMessage(incoming: AnyMessage) {
		if ('response' in incoming) {
			this.handleResponse(incoming);
		} else {
			const { name, payload, channel } = incoming;

			const responsePayload = await this.processMessage(name, payload);

			if (channel !== undefined) {
				// Communication partner wants to receive a response on this channel
				this.sendMessage({
					name,
					channel,
					response: responsePayload
				});
			}
		}
	}

	public send<T extends keyof SENT>(name: T, payload: Payload<SENT, T>) {
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
		this.handleIncomingMessage(incoming);
	}

	protected abstract processMessage<T extends keyof HANDLED>(
		name: T,
		payload: Payload<HANDLED, T>
	): Promise<Response<HANDLED, T>>;
	protected abstract sendOutgoingMessage(encodedMessage: string): void;
}
