import { expect, test } from 'vitest';
import { convertTemplateToHtml, defineTemplate } from './conversion';

test('Interpolate and convert mails from MJML to HTML', async () => {
	const layout = `
      <mjml>
        <mj-body>
          <mj-section>
            <mj-column>
              <mj-text>
                Hello World!
              </mj-text>
              <mj-text>
                \${customText}
              </mj-text>
            </mj-column>
          </mj-section>
        </mj-body>
      </mjml>
    `;

	const template = defineTemplate<{
		customText: string;
	}>(layout);

	const processed = await convertTemplateToHtml(template, {
		customText: 'This is my custom text :)'
	});

	expect(processed).toContain('This is my custom text :)');
	expect(processed).not.toContain('${customText}');
});
