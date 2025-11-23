// PGlite multi-tab worker entrypoint
// See docs: https://pglite.dev/docs/multi-tab-worker
import { PGlite } from "@electric-sql/pglite";
import { worker } from "@electric-sql/pglite/worker";
import { ltree } from "@electric-sql/pglite/contrib/ltree";
import { pg_trgm } from "@electric-sql/pglite/contrib/pg_trgm";
import { live } from "@electric-sql/pglite/live";

worker({
  async init() {
    // Single logical database persisted in IndexedDB
    return new PGlite("memory://haskell_cafe", {
      extensions: {
        live,
        ltree,
        pg_trgm,
      },
    });
  },
});
