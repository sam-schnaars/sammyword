import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // Served under /mobile/ (samarei.com/mobile proxies to this app; vercel.json
  // maps /mobile/* back to the root on sammyword's own domain).
  base: '/mobile/',
})
