import { defineTemplate } from './conversion';
import layoutActivateAccount from './templates/activate-account.mjml';

export const templateActivateAccount = defineTemplate<{
	activationCode: string;
	activationUrl: string;
}>(layoutActivateAccount);
