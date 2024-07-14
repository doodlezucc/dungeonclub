import mjml2html from 'mjml';

export interface MailTemplate<P> {
	mjmlLayout: string;
	defaultParams: Partial<P>;
}

export function defineTemplate<P>(mjmlLayout: string): MailTemplate<P> {
	return {
		mjmlLayout,
		defaultParams: {}
	};
}

function interpolateTemplate<P>(template: MailTemplate<P>, params: P) {
	const rawLayout = template.mjmlLayout;
	let interpolated = rawLayout;

	for (const key in params) {
		const variable = '${' + key + '}';
		const value = params[key];

		interpolated = interpolated.replaceAll(variable, `${value}`);
	}

	if (interpolated.includes('${')) {
		throw `Not all variables have been interpolated.\n${interpolated}`;
	}

	return interpolated;
}

export async function convertTemplateToHtml<P>(template: MailTemplate<P>, params: P) {
	const preprocessed = interpolateTemplate(template, params);

	const results = await mjml2html(preprocessed);

	if (results.errors.length) {
		for (const err of results.errors) {
			console.error(err);
		}

		throw 'Failed to convert MJML email template to HTML';
	}

	return results.html;
}
