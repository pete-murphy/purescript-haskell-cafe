// PGlite multi-tab worker entrypoint
// See docs: https://pglite.dev/docs/multi-tab-worker
import { PGlite } from "@electric-sql/pglite";
import { worker } from "@electric-sql/pglite/worker";
import { ltree } from "@electric-sql/pglite/contrib/ltree";
import { pg_trgm } from "@electric-sql/pglite/contrib/pg_trgm";
import { live } from "@electric-sql/pglite/live";
import { schemaSQL } from "./lib/schema.js";

let dbInstance;
let dbReady;

async function ensureDb() {
  if (dbInstance) return dbInstance;
  if (!dbReady) {
    dbReady = (async () => {
      const db = new PGlite("opfs-ahp://haskell_cafe", {
        relaxedDurability: true,
        extensions: {
          live,
          ltree,
          pg_trgm,
        },
      });
      await db.exec(schemaSQL);
      dbInstance = db;
      return db;
    })().catch((error) => {
      dbReady = null;
      throw error;
    });
  }
  return dbReady;
}

worker({
  async init() {
    return ensureDb();
  },
});
