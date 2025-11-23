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

async function main() {
  await new Promise((resolve) => setTimeout(resolve, 400));
  const pglite = await newPGlite();

  console.log("pglite", pglite);
  pglite.live.query({
    query: "SELECT * FROM messages ORDER BY date DESC;",
    offset: 0,
    limit: 10,
    callback: (res) => {
      console.log("res", res);
    },
  });
}

main();
