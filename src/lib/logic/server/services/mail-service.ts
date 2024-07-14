import { convertTemplateToHtml, type MailTemplate } from './mail/conversion';

export interface SendMailOptions {
	subject: string;
	recipient: string;
	htmlBody: string;
}

export interface SendTemplateMailOptions<P> {
	recipient: string;
	template: MailTemplate<P>;
	params: P;
}

export abstract class MailService {
	abstract sendMail(options: SendMailOptions): Promise<void>;

	async sendTemplateMail<P>(options: SendTemplateMailOptions<P>): Promise<void> {
		const { recipient, template, params } = options;
		const { subject } = template;

		const mjmlPreprocessed = await convertTemplateToHtml(template, params);

		await this.sendMail({
			subject,
			recipient,
			htmlBody: mjmlPreprocessed
		});
	}
}
