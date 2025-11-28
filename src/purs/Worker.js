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
      console.log(row);

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

    const query = `INSERT INTO messages (${fields.concat("search").join(", ")}) VALUES ${placeholders.join(", ")} ON CONFLICT DO NOTHING;`;

    return () => {
      return pglite.query(query, flattened);
    };
  };
}

export function queryMessages(pglite) {
  return () => pglite.query(`SELECT * FROM messages;`);
}

export function fetchSample(filename) {
  return () => {
    // let txt = txts[Math.floor(Math.random() * txts.length)];
    let txt = filename;
    // txt = "2022-April.txt";
    // return Promise.resolve(sample);
    // document.body.appendChild(document.createElement("h1")).textContent = txt;
    // self.postMessage({ type: "fetch", message: txt });
    if (txt.endsWith(".txt")) {
      return fetch(`/haskell-cafe/${txt}`).then((response) => response.text());
    } else {
      let sample = "";
      return fetch(`/haskell-cafe/${txt}`)
        .then((response) =>
          response.body
            .pipeThrough(new DecompressionStream("gzip"))
            .pipeThrough(new TextDecoderStream())
            .pipeTo(
              new WritableStream({
                write(chunk) {
                  sample += chunk;
                },
              })
            )
        )
        .then(() => (console.log(sample), sample));
    }
  };
}
