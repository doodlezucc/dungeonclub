import {
	GMAIL_API_CLIENT_ID,
	GMAIL_API_CLIENT_SECRET,
	GMAIL_API_REFRESH_TOKEN,
	GMAIL_API_USER
} from '$env/static/private';
import nodemailer, { type Transporter } from 'nodemailer';
import { prisma } from 'server/server';
import { MailService, type SendMailOptions } from '../mail-service';

const SETTING_KEY_TOKEN_STATE = 'GMAIL_TOKEN';
interface GmailTokenState {
	accessToken: string;
	expires: number;
}

export class GmailMailService extends MailService {
	private transporter: Transporter | null = null;

	constructor() {
		super();
		this.setupTransporter();
	}

	private async setupTransporter() {
		try {
			const state = await this.readState();

			this.transporter = GmailMailService.createTransporter(state);

			this.transporter.on('token', (token) => {
				this.storeToken({
					accessToken: token.accessToken,
					expires: token.expires
				});
			});
		} catch (err) {
			console.error('Failed to setup Gmail mailing service');
			console.error(err);
		}
	}

	private static createTransporter(tokenState: GmailTokenState): Transporter {
		return nodemailer.createTransport({
			host: 'smtp.gmail.com',
			port: 465,
			secure: true,
			auth: {
				type: 'OAuth2',
				user: GMAIL_API_USER,
				clientId: GMAIL_API_CLIENT_ID,
				clientSecret: GMAIL_API_CLIENT_SECRET,
				refreshToken: GMAIL_API_REFRESH_TOKEN,
				accessToken: tokenState.accessToken,
				expires: tokenState.expires
			}
		});
	}

	private async readState(): Promise<GmailTokenState> {
		const setting = await prisma.systemSetting.findFirstOrThrow({
			where: { key: SETTING_KEY_TOKEN_STATE }
		});

		return JSON.parse(setting.jsonValue);
	}

	private async storeToken(token: GmailTokenState) {
		const tokenJsonString = JSON.stringify(token);

		await prisma.systemSetting.update({
			where: { key: SETTING_KEY_TOKEN_STATE },
			data: {
				jsonValue: tokenJsonString
			}
		});
	}

	async sendMail(options: SendMailOptions): Promise<void> {
		const client = this.transporter;

		if (!client) {
			throw 'Transporter not initialized';
		}

		const result = await client.sendMail({
			subject: options.subject,
			from: { name: 'Dungeon Club', address: GMAIL_API_USER },
			to: options.recipient,
			html: options.htmlBody,
			attachments: [
				{
					cid: 'logo',
					filename: 'logo.png',
					content: await MailService.loadLogoImage()
				}
			]
		});

		console.log('Result after sending mail:', result);
	}
}
