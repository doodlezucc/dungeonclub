import { SMTP_HOST, SMTP_PASS, SMTP_PORT, SMTP_SECURE, SMTP_USER } from '$env/static/private';
import nodemailer from 'nodemailer';
import { TransporterMailService } from './transporter-service';

export class SMTPMailService extends TransporterMailService {
	protected async createTransporter() {
		return nodemailer.createTransport({
			host: SMTP_HOST,
			port: parseInt(SMTP_PORT),
			secure: SMTP_SECURE === 'true',
			auth: {
				user: SMTP_USER,
				pass: SMTP_PASS
			}
		});
	}
}
