/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  darkMode: 'class',
  theme: {
    extend: {
      fontFamily: {
        sans: [
          'Inter',
          'SF Pro Display',
          'SF Pro Text',
          'ui-sans-serif',
          'system-ui',
          'sans-serif',
        ],
        mono: ['SF Mono', 'Menlo', 'monospace'],
      },
    },
  },
  plugins: [],
};
