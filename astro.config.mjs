// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://tokelang.dev',
	integrations: [
		starlight({
			title: 'toke',
			logo: {
				light: './src/assets/toke-logo-light.svg',
				dark: './src/assets/toke-logo-dark.svg',
				replacesTitle: true,
			},
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/karwalski/toke' },
			],
			customCss: ['./src/styles/custom.css'],
			sidebar: [
				{
					label: 'About',
					items: [
						{ label: 'Why toke?', slug: 'about/why' },
						{ label: 'Design Principles', slug: 'about/design' },
						{ label: 'Project Repositories', slug: 'about/repos' },
						{ label: 'Changelog', slug: 'about/changelog' },
					],
				},
				{
					label: 'Getting Started',
					items: [
						{ label: 'Installation', slug: 'getting-started/install' },
						{ label: 'Hello World', slug: 'getting-started/hello-world' },
						{ label: 'Language Tour', slug: 'getting-started/tour' },
						{ label: 'Project Structure', slug: 'getting-started/project-structure' },
					],
				},
				{
					label: 'Learn toke',
					items: [
						{ label: 'Course Overview', slug: 'learn/overview' },
						{ label: '1. Why toke Exists', slug: 'learn/01-why-toke' },
						{ label: '2. Modules and Functions', slug: 'learn/02-modules-functions' },
						{ label: '3. Control Flow', slug: 'learn/03-control-flow' },
						{ label: '4. Collections', slug: 'learn/04-collections' },
						{ label: '5. Error Handling', slug: 'learn/05-errors' },
						{ label: '6. Strings and I/O', slug: 'learn/06-strings-io' },
						{ label: '7. Modules and Imports', slug: 'learn/07-modules-imports' },
						{ label: '8. Advanced Topics', slug: 'learn/08-advanced' },
						{ label: '9. Standard Library', slug: 'learn/09-stdlib' },
						{ label: '10. Build a Project', slug: 'learn/10-project' },
					],
				},
				{
					label: 'API Reference',
					items: [
						{ label: 'Type System', slug: 'reference/types' },
						{ label: 'Grammar', slug: 'reference/grammar' },
						{ label: 'Error Codes', slug: 'reference/errors' },
						{ label: 'Data Formats', slug: 'reference/data-formats' },
						{
							label: 'Standard Library',
							autogenerate: { directory: 'reference/stdlib' },
						},
					],
				},
				{
					label: 'How toke Was Built',
					items: [
						{ label: 'Encoding Design', slug: 'reference/phase2/overview' },
						{ label: 'Type Encoding', slug: 'reference/phase2/types' },
						{ label: 'Grammar Encoding', slug: 'reference/phase2/grammar' },
					],
				},
				{
					label: 'Community',
					items: [
						{ label: 'Contributing', slug: 'community/contributing' },
						{ label: 'For Enterprise', slug: 'community/enterprise' },
					],
				},
			],
		}),
	],
});
