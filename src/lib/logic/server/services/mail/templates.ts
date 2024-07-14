import layoutActivateAccount from '../mail-templates/activate-account.mjml';
import { defineTemplate } from './conversion';

export const templateActivateAccount = defineTemplate<{
	activationCode: string;
	activationUrl: string;
}>(layoutActivateAccount);
