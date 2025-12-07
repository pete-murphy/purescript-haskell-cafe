import React from "react";
import { useLiveQuery } from "@electric-sql/pglite-react";

interface Message {
  id: string;
  subject: string | null;
  author: string | null;
  date: string | null;
  in_reply_to: string[] | null;
  refs: string[] | null;
  content: string | null;
  month_file: string | null;
  path: string;
  search: string;
  level: number | null;
}

interface MessagesProps {
  searchQuery?: string;
}

const formatDate = (date: string | null) => {
  if (!date) return "Unknown date";
  const d = new Date(date);
  return d.toLocaleString(undefined, {
    dateStyle: "long",
    timeStyle: "short",
  });
};

export const Messages: React.FC<MessagesProps> = () => {
  const [searchQuery, setSearchQuery] = React.useState("thread");

  const query = React.useMemo(
    () =>
      searchQuery
        ? `WITH search_query AS (SELECT websearch_to_tsquery('english', $1) AS query) SELECT id, subject, author, date, in_reply_to, refs, month_file FROM messages, search_query WHERE search @@ search_query.query ORDER BY ts_rank_cd(search, search_query.query) DESC;`
        : `SELECT id, subject, author, date, in_reply_to, refs, month_file, path, nlevel(path) AS level FROM messages ORDER BY path;`,
    [searchQuery]
  );
  const params = React.useMemo(
    () => (searchQuery ? [searchQuery] : []),
    [searchQuery]
  );

  const queryResult = useLiveQuery<Message>(query, params);

  // LiveQueryResults has a rows property
  const messages = queryResult?.rows.slice(0, 100) ?? [];

  const rowCount = useLiveQuery<{ count: number }>(
    "SELECT COUNT(*) FROM messages;",
    []
  );

  const MAX_ROWS = 133_558;
  const progressPercentage =
    ((rowCount?.rows?.at(0)?.count ?? 0) / MAX_ROWS) * 100;

  return (
    <>
      <div>
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
      </div>
      <div className="container">
        <progress value={rowCount?.rows?.at(0)?.count ?? 0} max={MAX_ROWS} />{" "}
        {rowCount?.rows?.at(0)?.count?.toLocaleString()} out of{" "}
        {MAX_ROWS.toLocaleString()} ({progressPercentage.toFixed(2)}%)
      </div>
      <div className="container">
        <div className="">
          Matches {queryResult?.rows.length.toLocaleString()} out of{" "}
          {rowCount?.rows?.at(0)?.count?.toLocaleString() ?? "N/A"}
        </div>
      </div>
      <div className="container">
        {messages.map((row, index) => {
          // console.log("level", row.level);
          const hue = simpleHash(row.id) % 360;
          return (
            <React.Fragment key={row.id || index}>
              <div
                className="message"
                style={{ paddingLeft: `${(row.level ?? 0) * 20}px` }}
              >
                <div className="message-header">
                  <div className="message-subject">
                    {row.subject || "No subject"}
                  </div>
                  <div className="message-meta message-from">
                    From: {row.author || "Unknown"} | {formatDate(row.date)}
                  </div>
                  {row.id && (
                    <div className="message-meta">
                      ID: <ColoredID id={row.id} />
                    </div>
                  )}
                  {row.in_reply_to && row.in_reply_to.length > 0 && (
                    <div className="message-meta">
                      In-Reply-To:{" "}
                      {row.in_reply_to.map((id) => (
                        <ColoredID key={id} id={id} />
                      ))}
                    </div>
                  )}
                  {row.refs && row.refs.length > 0 && (
                    <div className="message-meta">
                      References:{" "}
                      {row.refs.map((id) => (
                        <ColoredID key={id} id={id} />
                      ))}
                    </div>
                  )}
                  {row.month_file && (
                    <div className="message-meta">File: {row.month_file}</div>
                  )}
                </div>
              </div>
              {index < messages.length - 1 && (
                <div className="message-separator"></div>
              )}
            </React.Fragment>
          );
        })}
      </div>
    </>
  );
};

function ColoredID(props: { id: string }) {
  const hue = simpleHash(props.id) % 360;
  return (
    <div
      style={
        {
          color: `var(--color-4)`,
          backgroundColor: `var(--color-14)`,
          "--color-hue": hue.toString(),
          "--c": "1",
          display: "inline-block",
          padding: "0.125rem 0.25rem",
          borderRadius: "0.125rem",
        } as React.CSSProperties
      }
    >
      {props.id}
    </div>
  );
}

function simpleHash(str: string) {
  let hash = 0;
  if (str.length === 0) return hash;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char; // A common, simple hashing algorithm
    hash |= 0; // Convert to 32-bit integer
  }
  return hash;
}
