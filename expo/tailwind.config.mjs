/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        canvas: '#050505',
        panel: '#0b0b0b',
        ink: '#f5f5f5',
        mute: '#a3a3a3',
        line: 'rgba(255,255,255,0.1)',
      },
      boxShadow: {
        halo: '0 40px 100px rgba(0, 0, 0, 0.38)',
      },
      letterSpacing: {
        tighterest: '-0.07em',
      },
      backgroundImage: {
        'hero-glow':
          'radial-gradient(circle at top center, rgba(255,255,255,0.12), transparent 32%), linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01))',
        'page-fade':
          'radial-gradient(circle at top center, rgba(255,255,255,0.08), transparent 34%), linear-gradient(180deg, #090909 0%, #050505 40%, #030303 100%)',
      },
      fontFamily: {
        sans: ['SF Pro Display', 'SF Pro Text', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['SF Mono', 'Menlo', 'monospace'],
      },
    },
  },
  plugins: [],
};
