import { PGliteWorker } from "@electric-sql/pglite/worker";

export async function newPGlite() {
  const dbWorker = new Worker(
    new URL("../../src/pglite-worker.js", import.meta.url),
    { type: "module" }
  );
  const pglite = new PGliteWorker(dbWorker);
  await pglite.waitReady;
  return pglite;
}

export function createSchema(pglite) {
  return () =>
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
}

export function insertMessages(pglite) {
  return (rows) => {
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

    // build ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10), ($11,$12,$13,$14,$15,$16,$17,$18,$19,$20) ...
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

    const query = `
      INSERT INTO messages 
        (${fields.concat("search").join(", ")}) VALUES ${placeholders.join(", ")} 
        ON CONFLICT DO NOTHING;
    `;

    return () => {
      return pglite.query(query, flattened);
    };
  };
}

export function queryMessages(pglite) {
  return () => pglite.query(`SELECT * FROM messages;`);
}

export function fetchChunk({ filename, callback }) {
  return () =>
    filename.endsWith(".gz")
      ? fetch(`/haskell-cafe/${filename}`).then((response) =>
          response.body
            .pipeThrough(new DecompressionStream("gzip"))
            .pipeThrough(new TextDecoderStream())
            .getReader()
            .read()
            .then(({ done, value }) =>
              callback({ chunk: value, isDone: done })()
            )
        )
      : fetch(`/haskell-cafe/${filename}`).then((response) =>
          response.body
            .pipeThrough(new TextDecoderStream())
            .getReader()
            .read()
            .then(({ done, value }) =>
              callback({ chunk: value, isDone: done })()
            )
        );
}
