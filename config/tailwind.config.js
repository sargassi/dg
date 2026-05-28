const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  darkMode: 'class',
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  safelist: [
    'dark:bg-blue-600',
    'dark:text-white',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Helvetica', 'Arial', ...defaultTheme.fontFamily.sans],
      },
      fontSize: {
        'xxs': '11px',
        'xxxl': '4rem',
      },
      colors: {
        accent: {
          DEFAULT: '#1E3581',
          50: '#eef2fb',
          100: '#d4ddf5',
          200: '#b0c1ec',
          300: '#7f9be0',
          400: '#4d72d3',
          500: '#2a52c5',
          600: '#1E3581',
          700: '#192d6e',
          800: '#14255b',
          900: '#0f1d48',
        },
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
