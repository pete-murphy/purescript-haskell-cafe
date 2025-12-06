import { PGliteWorker } from "@electric-sql/pglite/worker";
import { live } from "@electric-sql/pglite/live";

const worker = new Worker(new URL("../../src/worker.ts", import.meta.url), {
  type: "module",
});

const FORWARD_CHANNEL = "db-forward";

let pglitePromise;

async function ensurePGlite() {
  if (!pglitePromise) {
    pglitePromise = newPGlite();
  }
  return pglitePromise;
}

worker.onmessage = (d) => {
  const data = d.data;

  if (data && data.channel === FORWARD_CHANNEL) {
    handleDbForward(data);
    return;
  }

  if (data !== "DB_READY") return;
  const button = document.createElement("button");
  button.innerHTML = "Click to start fetching text files";
  button.onclick = () => worker.postMessage("go");
  document.body.appendChild(button);
};

export async function newPGlite() {
  const dbWorker = new Worker(
    new URL("../../src/pglite-worker.js", import.meta.url),
    { type: "module" }
  );
  const pglite = new PGliteWorker(dbWorker, {
    extensions: {
      live,
    },
  });
  await pglite.waitReady;
  return pglite;
}

function buildInsertQuery(rows) {
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

  const flattened = rows.flatMap(
    ({ id, subject, author, date, in_reply_to, refs, content, month_file }) => [
      id,
      subject,
      author,
      date,
      in_reply_to,
      refs,
      content,
      month_file,
      in_reply_to.concat(id).join("."),
    ]
  );

  const query = `INSERT INTO messages 
      (${fields.concat("search").join(", ")}) VALUES ${placeholders.join(", ")} 
      ON CONFLICT DO NOTHING;`;

  return { query, params: flattened };
}

async function handleDbForward(message) {
  const { id, op, payload } = message;
  const respond = (body) =>
    worker.postMessage({ channel: FORWARD_CHANNEL, id, ...body });

  try {
    const pglite = await ensurePGlite();

    switch (op) {
      case "init": {
        respond({ ok: true, result: { ready: true } });
        return;
      }
      case "exec": {
        await pglite.exec(payload?.sql ?? "");
        respond({ ok: true, result: null });
        return;
      }
      case "query": {
        const res = await pglite.query(
          payload?.sql ?? "",
          payload?.params ?? []
        );
        respond({ ok: true, result: res });
        return;
      }
      case "insertMessages": {
        const rows = payload?.rows ?? [];
        if (!rows.length) {
          respond({ ok: true, result: { rowsAffected: 0 } });
          return;
        }
        const label = `[forward insert] ${rows.length} rows`;
        console.time(label);
        const { query, params } = buildInsertQuery(rows);
        const res = await pglite.query(query, params);
        console.timeEnd(label);
        respond({
          ok: true,
          result: { rowsAffected: res?.rowCount ?? rows.length },
        });
        return;
      }
      case "reset": {
        await pglite.exec("DELETE FROM messages;");
        respond({ ok: true, result: null });
        return;
      }
      default:
        throw new Error(`Unknown forward op: ${op}`);
    }
  } catch (error) {
    respond({
      ok: false,
      error: {
        message: error?.message || "forwarding error",
        stack: error?.stack,
      },
    });
  }
}

function renderMessages(res, appElement) {
  const { rows, offset } = res;

  const formatDate = (date) => {
    if (!date) return "Unknown date";
    const d = new Date(date);
    return d.toLocaleString(undefined, {
      dateStyle: "long",
      timeStyle: "short",
    });
  };

  const escapeHtml = (text) => {
    if (!text) return "";
    return text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  };

  const html = `
    <div class="container">
      ${
        rows.length === 0
          ? "No messages found"
          : rows
              .map(
                (row, index) => `
        <div class="message">
          <div class="message-header">
            <div class="message-subject">${escapeHtml(row.subject || "No subject")}</div>
            <div class="message-meta message-from">
              From: ${escapeHtml(row.author || "Unknown")} | ${formatDate(row.date)}
            </div>
            ${row.id ? `<div class="message-meta">ID: ${escapeHtml(row.id)}</div>` : ""}
            ${row.in_reply_to.length > 0 ? `<div class="message-meta">In-Reply-To: ${row.in_reply_to.map((ref) => escapeHtml(ref)).join(", ")}</div>` : ""}
            ${row.month_file ? `<div class="message-meta">File: ${escapeHtml(row.month_file)}</div>` : ""}
          </div>

        </div>
        ${index < rows.length - 1 ? '<div class="message-separator"></div>' : ""}`
              )
              .join("")
      }
    </div>
  `;

  appElement.innerHTML = html;
}

export function liveQuery(pglite) {
  console.log("[liveQuery] Starting live query");
  const app = document.getElementById("app");
  // Ensure schema (TODO: move this to a shared file, it is duplicated in Worker.js)
  pglite.exec(`
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
  `);

  pglite.live.query({
    query:
      "SELECT * FROM messages WHERE search @@ websearch_to_tsquery('english', 'thread') ORDER BY date ASC;",
    // query: "SELECT * FROM messages ORDER BY date ASC;",
    offset: 0,
    limit: 100,
    callback: (res) => {
      console.log(
        humanReadableTimestamp(),
        "[PGlite] live query callback",
        res.rows.length
      );
      requestAnimationFrame(() => renderMessages(res, app));
    },
  });
  pglite.live.query({
    query: "SELECT COUNT(*) FROM messages;",
    callback: (res) => {
      console.log(
        humanReadableTimestamp(),
        "[PGlite] live query callback, count of rows",
        res.rows.at(0)?.count
      );
    },
  });
}

function humanReadableTimestamp() {
  const now = Math.floor(performance.now());
  const seconds = now / 1_000;
  return seconds.toPrecision(3);
}
