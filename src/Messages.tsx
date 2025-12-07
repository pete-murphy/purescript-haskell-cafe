import React from "react";
import { useDebounce } from "@uidotdev/usehooks";
import { useLiveQuery, usePGlite } from "@electric-sql/pglite-react";
import { deleteMessagesTableSQL, schemaSQL } from "./lib/schema.js";

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
  const debouncedSearchQuery = useDebounce(searchQuery, 200);
  const [tableVersion, setTableVersion] = React.useState(0);
  const db = usePGlite();

  const query = React.useMemo(
    () =>
      debouncedSearchQuery
        ? `-- version: ${tableVersion}\n
          WITH search_query AS (SELECT websearch_to_tsquery('english', $1) AS query)
          SELECT
            id, subject, author, date, in_reply_to, refs, month_file, path, nlevel(path) AS level
          FROM messages, search_query
          WHERE search @@ search_query.query
          ORDER BY ts_rank_cd(search, search_query.query) ASC
          LIMIT 100;`
        : `-- version: ${tableVersion}\n
          WITH messages_with_min_date AS (
            SELECT 
              id, subject, author, date, in_reply_to, refs, month_file, path, nlevel(path) AS level,
              MIN(date) OVER (PARTITION BY subject) AS min_subject_date
            FROM messages
          )
          SELECT 
            id, subject, author, date, in_reply_to, refs, month_file, path, level
          FROM messages_with_min_date
          ORDER BY min_subject_date, subject, date ASC
          LIMIT 100;`,
    [debouncedSearchQuery, tableVersion]
  );
  const params = React.useMemo(
    () => (debouncedSearchQuery ? [debouncedSearchQuery] : []),
    [debouncedSearchQuery]
  );

  const queryResult = useLiveQuery<Message>(query, params);

  // LiveQueryResults has a rows property
  const messages = queryResult?.rows.slice(0, 100) ?? [];

  const countQuery = React.useMemo(
    () => `-- version: ${tableVersion}\nSELECT COUNT(*) FROM messages;`,
    [tableVersion]
  );
  const rowCount = useLiveQuery<{ count: number }>(countQuery, []);

  const MAX_ROWS = 133_558;
  const progressPercentage =
    ((rowCount?.rows?.at(0)?.count ?? 0) / MAX_ROWS) * 100;

  const handleDelete = async () => {
    if (
      !confirm(
        "Are you sure you want to delete all messages? This cannot be undone."
      )
    ) {
      return;
    }
    try {
      await db.exec(deleteMessagesTableSQL);
      await db.exec(schemaSQL);
      // Force live queries to restart by incrementing table version
      setTableVersion((v) => v + 1);
    } catch (error) {
      console.error("Error deleting messages table:", error);
      alert("Failed to delete messages table. See console for details.");
    }
  };

  const handleCreateTable = async () => {
    try {
      await db.exec(schemaSQL);
      // Force live queries to restart by incrementing table version
      setTableVersion((v) => v + 1);
    } catch (error) {
      console.error("Error creating messages table:", error);
      alert("Failed to create messages table. See console for details.");
    }
  };

  return (
    <>
      <div className="font-sans mb-8 space-y-6">
        {/* Search and Actions */}
        <div className="flex items-center gap-3">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search messages..."
            className="flex-1 px-4 py-2 bg-slate-900/50 border border-slate-800 rounded-lg text-slate-50 placeholder-slate-500 text-sm font-normal focus:outline-none focus:ring-2 focus:ring-slate-700 focus:border-slate-700 transition-all"
          />
          <button
            onClick={handleCreateTable}
            className="px-4 py-2 bg-white text-slate-950 hover:bg-slate-100 rounded-lg text-sm font-medium transition-colors"
          >
            Create Table
          </button>
          <button
            onClick={handleDelete}
            className="px-4 py-2 bg-slate-800 text-slate-200 hover:bg-slate-700 rounded-lg text-sm font-medium transition-colors"
          >
            Delete All
          </button>
        </div>

        {/* Progress Section */}
        <div className="space-y-2">
          <div className="flex items-center justify-between text-sm">
            <span className="text-slate-400 font-normal">Loading progress</span>
            <span className="text-slate-300 font-medium">
              {rowCount?.rows?.at(0)?.count?.toLocaleString()} /{" "}
              {MAX_ROWS.toLocaleString()} ({progressPercentage.toFixed(1)}%)
            </span>
          </div>
          <div className="h-2 bg-slate-900 rounded-full overflow-hidden">
            <div
              className="h-full bg-white transition-all duration-300"
              style={{ width: `${progressPercentage}%` }}
            />
          </div>
        </div>

        {/* Results Summary */}
        <div className="flex items-center gap-2 text-sm">
          <span className="text-slate-400">Showing</span>
          <span className="text-slate-200 font-medium">
            {queryResult?.rows.length.toLocaleString()}
          </span>
          <span className="text-slate-400">of</span>
          <span className="text-slate-200 font-medium">
            {rowCount?.rows?.at(0)?.count?.toLocaleString() ?? "N/A"}
          </span>
          <span className="text-slate-400">messages</span>
        </div>
      </div>
      <div className="font-mono">
        {messages.map((row, index) => {
          // console.log("level", row.level);
          const hue = simpleHash(row.id) % 360;
          return (
            <React.Fragment key={row.id || index}>
              <div
                className="mb-0"
                style={{ paddingLeft: `${(row.level ?? 0) * 20}px` }}
              >
                <div className="mb-0 text-slate-200">
                  <div className="text-slate-200 font-black text-base mb-0 font-sans">
                    {row.subject || "No subject"}
                  </div>
                  <div className="text-xs text-slate-200 mb-1">
                    From: {row.author || "Unknown"} | {formatDate(row.date)}
                  </div>
                  {row.id && (
                    <div className="text-xs text-slate-500 mb-1">
                      ID: <ColoredID id={row.id} />
                    </div>
                  )}
                  {row.in_reply_to && row.in_reply_to.length > 0 && (
                    <div className="text-xs text-slate-500 mb-1">
                      In-Reply-To:{" "}
                      {row.in_reply_to.map((id) => (
                        <ColoredID key={id} id={id} />
                      ))}
                    </div>
                  )}
                  {row.refs && row.refs.length > 0 && (
                    <div className="text-xs text-slate-500 mb-1">
                      References:{" "}
                      {row.refs.map((id) => (
                        <ColoredID key={id} id={id} />
                      ))}
                    </div>
                  )}
                  {row.month_file && (
                    <div className="text-xs text-slate-500 mb-1">
                      File: {row.month_file}
                    </div>
                  )}
                </div>
              </div>
              {index < messages.length - 1 && (
                <div className="border-t border-slate-900"></div>
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
      className="inline-block px-1 py-0.5 rounded"
      style={
        {
          color: `var(--color-4)`,
          backgroundColor: `var(--color-14)`,
          "--color-hue": hue.toString(),
          "--c": "1",
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
