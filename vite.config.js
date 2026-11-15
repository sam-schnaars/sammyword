import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { fileURLToPath } from 'node:url'

const page = (p) => fileURLToPath(new URL(p, import.meta.url))

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // Served under /mobile/ (samarei.com/mobile proxies to this app; vercel.json
  // maps /mobile/* back to the root on sammyword's own domain).
  base: '/mobile/',
  // Extra standalone pages: the pixel-art redesign concepts (/mobile/concepts/).
  build: {
    rollupOptions: {
      input: {
        main: page('index.html'),
        concepts: page('concepts/index.html'),
        mine: page('concepts/mine.html'),
        liftoff: page('concepts/liftoff.html'),
        duel: page('concepts/duel.html'),
      },
    },
  },
})
