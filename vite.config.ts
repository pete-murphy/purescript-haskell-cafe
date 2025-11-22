import { defineConfig } from "vite";

// https://vite.dev/config/
export default defineConfig({
  worker: {
    format: "es",
  },
  server: {
    proxy: {
      "/haskell-cafe": {
        target: "https://mail.haskell.org/pipermail",
        changeOrigin: true,
      },
    },
  },
});
