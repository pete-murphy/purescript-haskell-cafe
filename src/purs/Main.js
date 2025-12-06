import { PGliteWorker } from "@electric-sql/pglite/worker";
import { live } from "@electric-sql/pglite/live";

const worker = new Worker(new URL("../../src/worker.ts", import.meta.url), {
  type: "module",
});

worker.onmessage = (d) => {
  if (d.data !== "DB_READY");
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

  // <div class="message-content">${escapeHtml(row.content || "")}</div>

  // ${
  //   row.refs && row.refs.length > 0
  //     ? `<div class="message-footer">References: ${row.refs.map((ref) => escapeHtml(ref)).join(", ")}</div>`
  //     : ""
  // }
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
    query: "SELECT * FROM messages ORDER BY date ASC;",
    offset: 0,
    limit: 100,
    callback: (res) => {
      console.log(
        performance.now(),
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
        performance.now(),
        "[PGlite] live query callback, count of rows",
        res.rows.at(0)?.count
      );
    },
  });
}
