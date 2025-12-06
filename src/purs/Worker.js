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

let count = 0;

export function insertMessages({ pglite, rows }) {
  return (affError, affSuccess) => {
    if (rows.length === 0) {
      return affSuccess({ rows: [], rowsAffected: 0 });
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
    const k = count++;
    const rowsLength = rows.length;
    const query = `INSERT INTO messages 
        (${fields.concat("search").join(", ")}) VALUES ${placeholders.join(", ")} 
        ON CONFLICT DO NOTHING;`;

    const label = `INSERTING ${k} (${rowsLength} rows)`;
    console.time(label);
    pglite
      .query(query, flattened)
      .then(affSuccess)
      .catch(affError)
      .finally(() => console.timeEnd(label));

    return (_cancelError, _onCancelerError, onCancelerSuccess) => {
      // TODO: Handle cancellation?
      onCancelerSuccess();
    };
  };
}

export function queryMessages(pglite) {
  return () => pglite.query(`SELECT * FROM messages;`);
}

export function fetchStreamImpl({ filename, onChunk }) {
  return (affError, affSuccess) => {
    const controller = new AbortController();
    fetchStream(filename, onChunk).then(affSuccess).catch(affError);
    return (error, _cancelError, cancelSuccess) => {
      controller.abort(error);
      cancelSuccess();
    };
  };
}

async function fetchStream(filename, onChunk) {
  const res = await fetch(`/haskell-cafe/${filename}`);
  const decoded = (
    filename.endsWith(".gz")
      ? res.body.pipeThrough(new DecompressionStream("gzip"))
      : res.body
  ).pipeThrough(new TextDecoderStream());
  const reader = decoded.getReader();

  while (true) {
    const { done, value } = await reader.read();
    if (done) {
      onChunk(null)();
      break;
    }
    onChunk(value)();
  }
}
