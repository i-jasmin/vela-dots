// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// Published by .github/workflows/docs.yml to GitHub Pages, under the repo's
// name: https://i-jasmin.github.io/vela-dots/
export default defineConfig({
	site: 'https://i-jasmin.github.io',
	base: '/vela-dots',
	integrations: [
		starlight({
			title: 'vela',
			description: 'A Hyprland desktop for Fedora, built on Quickshell and retinted from your wallpaper.',
			logo: { light: './src/assets/logo-light.svg', dark: './src/assets/logo-dark.svg' },
			favicon: '/favicon.svg',
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/i-jasmin/vela-dots' }],
			customCss: ['./src/styles/custom.css'],
			lastUpdated: false,
			sidebar: [
				{
					label: 'Start here',
					items: [
						{ label: 'Install', slug: 'start/install' },
						{ label: 'First steps', slug: 'start/first-steps' },
						{ label: 'Update and uninstall', slug: 'start/update' },
					],
				},
				{
					label: 'Using vela',
					items: [
						{ label: 'The bar', slug: 'features/bar' },
						{ label: 'Dashboard', slug: 'features/dashboard' },
						{ label: 'Calendar', slug: 'features/calendar' },
						{ label: 'Notifications', slug: 'features/notifications' },
						{ label: 'Launcher', slug: 'features/launcher' },
						{ label: 'Windows and workspaces', slug: 'features/windows' },
						{ label: 'Sessions', slug: 'features/sessions' },
						{ label: 'Wallpapers and colours', slug: 'features/theming' },
						{ label: 'Lock screen and idle', slug: 'features/lock' },
						{ label: 'Capture and clipboard', slug: 'features/capture' },
						{ label: 'The dock', slug: 'features/dock' },
					],
				},
				{
					label: 'Configure',
					items: [
						{ label: 'Settings', slug: 'configure/settings' },
						{ label: 'Hyprland and this machine', slug: 'configure/hyprland' },
						{ label: 'Keybinds', slug: 'configure/keybinds' },
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'The vela command', slug: 'reference/cli' },
						{ label: 'IPC', slug: 'reference/ipc' },
					],
				},
				{
					label: 'Help',
					items: [
						{ label: 'Troubleshooting', slug: 'help/troubleshooting' },
						{ label: 'NVIDIA', slug: 'help/nvidia' },
						{ label: 'FAQ', slug: 'help/faq' },
					],
				},
				{
					label: 'Contributing',
					items: [{ label: 'How it is built', slug: 'contributing/architecture' }],
				},
			],
		}),
	],
});
