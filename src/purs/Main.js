import { PGliteWorker } from "@electric-sql/pglite/worker";
import { live } from "@electric-sql/pglite/live";

export function worker() {
  return new Worker(new URL("../../src/worker.ts", import.meta.url), {
    type: "module",
  });
}

export function onMessages(worker) {
  return (callback) => {
    return () =>
      (worker.onmessage = (event) => {
        if (event.data.type === "fetch") {
          document.body.appendChild(document.createElement("h1")).textContent =
            event.data.message;
        } else callback(event.data.message)();
      });
  };
}

export function addToDOM(message) {
  return () => {
    document.body.appendChild(document.createElement("pre")).textContent =
      message;
  };
}

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
            ${row.in_reply_to ? `<div class="message-meta">In-Reply-To: ${escapeHtml(row.in_reply_to)}</div>` : ""}
            ${row.month_file ? `<div class="message-meta">File: ${escapeHtml(row.month_file)}</div>` : ""}
          </div>
          
          <div class="message-content">${escapeHtml(row.content || "")}</div>
          
          ${
            row.refs && row.refs.length > 0
              ? `<div class="message-footer">References: ${row.refs.map((ref) => escapeHtml(ref)).join(", ")}</div>`
              : ""
          }
        </div>
        ${index < rows.length - 1 ? '<div class="message-separator"></div>' : ""}
      `
              )
              .join("")
      }
    </div>
  `;

  appElement.innerHTML = html;
}

async function main() {
  const app = document.getElementById("app");
  await new Promise((resolve) => setTimeout(resolve, 400));
  const pglite = await newPGlite();
  pglite.live.query({
    query: "SELECT * FROM messages ORDER BY date DESC;",
    offset: 0,
    limit: 100,
    callback: (res) => {
      console.log("res", res);
      renderMessages(res, app);
    },
  });
}

main();
