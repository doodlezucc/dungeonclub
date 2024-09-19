import {
	SMTP_HOST,
	SMTP_PORT,
	SMTP_SECURE,
	SMTP_USER,
	SMTP_PASS,
	SMTP_FROM_NAME,
	SMTP_FROM_EMAIL
} from '$env/static/private';
import nodemailer, { type Transporter } from 'nodemailer';
import { MailService, type SendMailOptions } from '../mail-service';

export class SMTPMailService extends MailService {
	private transporter: Transporter | null = null;

	constructor() {
		super();
		this.setupTransporter();
	}

	private setupTransporter() {
		try {
			this.transporter = nodemailer.createTransport({
				host: SMTP_HOST,
				port: parseInt(SMTP_PORT),
				secure: SMTP_SECURE === 'true',
				auth: {
					user: SMTP_USER,
					pass: SMTP_PASS
				}
			});
		} catch (err) {
			console.error('Failed to setup SMTP mailing service');
			console.error(err);
		}
	}

	async sendMail(options: SendMailOptions): Promise<void> {
		const client = this.transporter;

		if (!client) {
			throw 'Transporter not initialized';
		}

		const result = await client.sendMail({
			subject: options.subject,
			from: { name: SMTP_FROM_NAME, address: SMTP_FROM_EMAIL },
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