module.exports = {
  content: [
    './js/**/*.js',
    '../lib/feedback_bot_web.ex',
    '../lib/feedback_bot_web/**/*.*ex'
  ],
  theme: {
    extend: {
      colors: {
        brand: '#FD4F00',
      },
      fontFamily: {
        sans: [
          'ui-sans-serif',
          'system-ui',
          'sans-serif',
          'Apple Color Emoji',
          'Segoe UI Emoji',
          'Segoe UI Symbol',
          'Noto Color Emoji'
        ],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
  ]
}
