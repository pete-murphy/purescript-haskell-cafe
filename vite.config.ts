import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import path from "path";

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
    dedupe: ["tslib"],
  },
  worker: {
    format: "es",
  },
  optimizeDeps: {
    exclude: ["@electric-sql/pglite"],
    include: ["tslib", "react-remove-scroll", "use-sidecar"],
    esbuildOptions: {
      resolveExtensions: [".js", ".jsx", ".ts", ".tsx"],
    },
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
