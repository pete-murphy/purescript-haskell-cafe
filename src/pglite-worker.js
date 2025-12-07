// PGlite multi-tab worker entrypoint
// See docs: https://pglite.dev/docs/multi-tab-worker
import { PGlite } from "@electric-sql/pglite";
import { worker } from "@electric-sql/pglite/worker";
import { ltree } from "@electric-sql/pglite/contrib/ltree";
import { pg_trgm } from "@electric-sql/pglite/contrib/pg_trgm";
import { live } from "@electric-sql/pglite/live";

const RPC_CHANNEL = "pglite-rpc";

const schemaSQL = `
  CREATE EXTENSION IF NOT EXISTS ltree;
  CREATE EXTENSION IF NOT EXISTS pg_trgm;
  CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    subject TEXT,
    author TEXT,
    date TIMESTAMPTZ,
    in_reply_to TEXT[],
    refs TEXT[],
    content TEXT,
    month_file TEXT,
    path LTREE NOT NULL,
    search TSVECTOR NOT NULL
  );
`;

let dbInstance;
let dbReady;

async function ensureDb() {
  if (dbInstance) return dbInstance;
  if (!dbReady) {
    dbReady = (async () => {
      const db = new PGlite("memory://haskell_cafe", {
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

function serializeError(error) {
  if (!error) return { message: "Unknown error" };
  if (typeof error === "string") return { message: error };
  return { message: error.message || "Unknown error", stack: error.stack };
}

async function handleInsertMessages(db, rows) {
  if (!rows || rows.length === 0) {
    return { rowsAffected: 0 };
  }

  const fields = [
    "id",
    "subject",
    "author",
    "date",
    "in_reply_to",
    "refs",
    "content",
    "month_file",
    "path",
  ];

  const placeholders = rows.map(
    (_, i) =>
      `(${fields
        .map((_, j) => `$${fields.length * i + j + 1}`)
        .concat(
          `to_tsvector('english', $${i * fields.length + 2} || ' ' || $${i * fields.length + 3} || ' ' || $${i * fields.length + 7})`
        )
        .join(", ")})`
  );

  const flattened = rows.flatMap((row) => {
    const {
      id,
      subject,
      author,
      date,
      in_reply_to,
      refs,
      content,
      month_file,
    } = row;

    return [
      id,
      subject,
      author,
      date,
      in_reply_to,
      refs,
      content,
      month_file,
      in_reply_to.concat(id).join("."),
    ];
  });

  const label = `[insertMessages] Inserting ${rows.length} rows`;
  console.time(label);
  const query = `INSERT INTO messages 
      (${fields.concat("search").join(", ")}) VALUES ${placeholders.join(", ")} 
      ON CONFLICT DO NOTHING;`;

  console.log("[handleMessage] query", query);
  const res = await db.query(query, flattened);
  console.timeEnd(label);
  return { rowsAffected: res?.rowCount ?? rows.length };
}

self.addEventListener("message", (event) => {
  const data = event.data;
  if (!data || data.channel !== RPC_CHANNEL) return;

  const { id, op, payload } = data;

  const respond = (body) =>
    self.postMessage({ channel: RPC_CHANNEL, id, ...body });

  (async () => {
    console.log("[handleMessage] data", data);
    console.log("[handleMessage] op", op);
    try {
      const db = await ensureDb();
      switch (op) {
        case "init":
          respond({ ok: true, result: { ready: true } });
          return;
        case "exec":
          await db.exec(payload?.sql ?? "");
          respond({ ok: true, result: null });
          return;
        case "query":
          respond({
            ok: true,
            result: await db.query(payload?.sql ?? "", payload?.params ?? []),
          });
          return;
        case "insertMessages":
          respond({
            ok: true,
            result: await handleInsertMessages(db, payload?.rows ?? []),
          });
          return;
        case "reset":
          await db.exec("DELETE FROM messages;");
          respond({ ok: true, result: null });
          return;
        default:
          throw new Error(`Unknown op: ${op}`);
      }
    } catch (error) {
      respond({ ok: false, error: serializeError(error) });
    }
  })();
});
