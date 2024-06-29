import { PrismaClient } from '@prisma/client';
import type { WebSocket } from 'ws';
import { Connection } from './connection';
import { IWebSocketManager, setupWebSocketServer } from './web-socket-server';

export const prisma = new PrismaClient();

export class Server {
	readonly webSocketManager = new WebSocketManager();
	readonly connections: Connection[] = [];

	async start() {
		this.webSocketManager.start();
	}
}

class WebSocketManager extends IWebSocketManager {
	connections: Connection[] = [];

	start() {
		setupWebSocketServer();
	}

	onConnect(socket: WebSocket) {
		const connection = new Connection(socket);

		socket.on('close', (code) => {
			this.onDisconnect(connection, code);
		});

		this.connections.push(connection);
	}

	private onDisconnect(connection: Connection, code: number) {
		console.log('Closing connection with code', code);
		this.connections = this.connections.filter((conn) => conn !== connection);
	}
}
