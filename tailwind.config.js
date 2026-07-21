/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        display: ['"Bricolage Grotesque"', 'system-ui', 'sans-serif'],
        sans: ['"Instrument Sans"', 'system-ui', 'sans-serif'],
        serif: ['Fraunces', 'Georgia', 'serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'monospace'],
      },
      colors: {
        "stitch": {
          "dark": "#0b1120",
          "surface": "rgba(30, 41, 59, 0.55)",
          "cyan": "#22d3ee",
          "green": "#34d399",
          "pink": "#f472b6",
          "text-primary": "#f1f5f9",
          "text-secondary": "#cbd5e1",
          "text-muted": "#94a3b8",
        },
        // Level accents (roadmap nodes + difficulty badges) — rgb form keeps /opacity working
        "level": {
          "beginner": "rgb(52 211 153 / <alpha-value>)",
          "intermediate": "rgb(59 130 246 / <alpha-value>)",
          "advanced": "rgb(167 139 250 / <alpha-value>)",
          "expert": "rgb(244 114 182 / <alpha-value>)",
        },
      },
      boxShadow: {
        "glow-primary": "0 0 20px rgba(34, 211, 238, 0.4)",
        "glow-secondary": "0 0 15px rgba(74, 222, 128, 0.3)",
        "glow-tertiary": "0 0 15px rgba(236, 72, 153, 0.3)",
        "glow-lg": "0 0 30px rgba(34, 211, 238, 0.6)",
      },
      backdropBlur: {
        "glass": "blur(30px)",
      },
      animation: {
        "glow": "glow-pulse 2s ease-in-out infinite",
        "float": "float 3s ease-in-out infinite",
        "scan": "scan-lines 20s linear infinite",
        "pulse-glow": "pulse-glow 1s ease-in-out infinite",
      },
      keyframes: {
        "glow-pulse": {
          "0%, 100%": { boxShadow: "0 0 20px rgba(34, 211, 238, 0.4)" },
          "50%": { boxShadow: "0 0 40px rgba(34, 211, 238, 0.8)" },
        },
        "float": {
          "0%, 100%": { transform: "translateY(0px)" },
          "50%": { transform: "translateY(-10px)" },
        },
        "scan-lines": {
          "0%": { transform: "translateY(0)" },
          "100%": { transform: "translateY(10px)" },
        },
        "pulse-glow": {
          "0%, 100%": { opacity: "1" },
          "50%": { opacity: "0.5" },
        },
      },
    },
  },
  plugins: [],
}
