import { defineConfig } from "vite";

// https://vite.dev/config/
export default defineConfig({
  worker: {
    format: "es",
  },
  optimizeDeps: {
    exclude: ["@electric-sql/pglite"],
  },
  server: {
    proxy: {
      "/haskell-cafe": {
        // target: "https://mail.haskell.org/pipermail",
        target: "http://localhost:8080",
        changeOrigin: true,
      },
    },
  },
});
