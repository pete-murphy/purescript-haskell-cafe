export const schemaSQL = `
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
  CREATE INDEX IF NOT EXISTS messages_search_idx ON messages USING GIN (search);
`;

export const deleteMessagesTableSQL = `DROP TABLE IF EXISTS messages CASCADE;`;
