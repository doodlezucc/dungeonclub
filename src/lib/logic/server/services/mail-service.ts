export interface SendMailOptions {
	subject: string;
	recipient: string;
	body: string;
}

export abstract class MailService {
	abstract sendMail(options: SendMailOptions): Promise<void>;
}
