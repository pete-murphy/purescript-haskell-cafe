const FORWARD_CHANNEL = "db-forward";

let forwardRequestId = 0;
const forwardPending = new Map();

self.addEventListener("message", (event) => {
  const data = event.data;
  if (!data || data.channel !== FORWARD_CHANNEL) return;
  const { id, ok, result, error } = data;
  const pending = forwardPending.get(id);
  if (!pending) return;
  forwardPending.delete(id);
  if (ok) {
    pending.resolve(result);
  } else {
    const message =
      (error && error.message) || "Database forward error from main thread";
    pending.reject(Object.assign(new Error(message), { cause: error }));
  }
});

function callMain(op, payload, transfer = []) {
  const id = ++forwardRequestId;
  const message = { channel: FORWARD_CHANNEL, id, op, payload };
  return new Promise((resolve, reject) => {
    forwardPending.set(id, { resolve, reject });
    self.postMessage(message, transfer);
  });
}

export function consoleCount(label) {
  console.count(label);
}

export async function newPGlite() {
  // The DB now lives behind the main thread's PGliteWorker. We forward calls.
  await callMain("init");
  return {
    exec: (sql) => callMain("exec", { sql }),
    query: (sql, params = []) => callMain("query", { sql, params }),
    insertMessages: (rows) => callMain("insertMessages", { rows }),
    reset: () => callMain("reset"),
    terminate: () => Promise.resolve(), // no-op in this proxy
  };
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

    pglite
      .insertMessages(rows)
      .then((result) =>
        affSuccess(result ?? { rowsAffected: rows.length, rows })
      )
      .catch(affError);

    return (_cancelError, _onCancelerError, onCancelerSuccess) => {
      // TODO: Handle cancellation?
      onCancelerSuccess();
    };
  };
}

export function queryMessages(pglite) {
  return () => pglite.query(`SELECT * FROM messages;`);
}

export function fetchText({ filename, onChunk }) {
  return (affError, affSuccess) => {
    const controller = new AbortController();
    fetchTextHelper(filename, onChunk).then(affSuccess).catch(affError);
    return (error, _cancelError, cancelSuccess) => {
      controller.abort(error);
      cancelSuccess();
    };
  };
}

async function fetchTextHelper(filename, onChunk) {
  console.count("fetchText");
  console.log(`[fetchText] fetching ${filename}`);
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

export function setupListener(callback) {
  self.onmessage = (data) => {
    callback();
  };
}

export function postMessage(string) {
  self.postMessage(string);
}
