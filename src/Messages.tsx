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
        ? `SELECT * FROM messages WHERE search @@ websearch_to_tsquery('english', $1) ORDER BY date ASC LIMIT 100;`
        : `SELECT * FROM messages ORDER BY date ASC LIMIT 100;`,
    [searchQuery]
  );
  const params = React.useMemo(
    () => (searchQuery ? [searchQuery] : []),
    [searchQuery]
  );

  const queryResult = useLiveQuery<Message>(query, params);

  // LiveQueryResults has a rows property
  const messages = queryResult?.rows ?? [];

  // if (!queryResult) {
  //   return <div className="container">Loading...</div>;
  // }

  // if (messages.length === 0) {
  //   return <div className="container">No messages found</div>;
  // }

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
        {messages.map((row, index) => (
          <React.Fragment key={row.id || index}>
            <div className="message">
              <div className="message-header">
                <div className="message-subject">
                  {row.subject || "No subject"}
                </div>
                <div className="message-meta message-from">
                  From: {row.author || "Unknown"} | {formatDate(row.date)}
                </div>
                {row.id && <div className="message-meta">ID: {row.id}</div>}
                {row.in_reply_to && row.in_reply_to.length > 0 && (
                  <div className="message-meta">
                    In-Reply-To: {row.in_reply_to.join(", ")}
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
        ))}
      </div>
    </>
  );
};
