/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Extracted from your Flutter App
        primary: '#88C999',      // The UCO Green
        dark: '#2E3440',         // The Dark Slate background
        'dark-light': '#434C5E', // The lighter gradient color from mobile home
        background: '#F8F9FA',   // The app background color
        surface: '#FFFFFF',
        'text-main': '#1F2937',
        'text-sub': '#9CA3AF',
      },
      fontFamily: {
        // Use system fonts that mimic SF Pro Display
        sans: ['-apple-system', 'BlinkMacSystemFont', 'Inter', 'Segoe UI', 'Roboto', 'sans-serif'],
      },
      borderRadius: {
        'xl': '16px',
        '2xl': '24px',
      }
    },
  },
  plugins: [],
};