import React from "react";
import { useDebounce } from "@uidotdev/usehooks";
import { useLiveQuery, usePGlite } from "@electric-sql/pglite-react";
import { format } from "date-fns";
import { parseDate } from "chrono-node";
import { Calendar as CalendarIcon } from "lucide-react";
// @ts-ignore
import { deleteMessagesTableSQL, schemaSQL } from "./lib/schema.js";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Calendar } from "@/components/ui/calendar";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";

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

function formatDateForDisplay(date: Date | undefined) {
  if (!date) {
    return "";
  }
  return date.toLocaleDateString("en-US", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  });
}

export const Messages: React.FC<MessagesProps> = () => {
  const [searchQuery, setSearchQuery] = React.useState("thread");
  const debouncedSearchQuery = useDebounce(searchQuery, 200);
  const [minDate, setMinDate] = React.useState<Date | undefined>(undefined);
  const [dateInputValue, setDateInputValue] = React.useState("");
  const [datePickerOpen, setDatePickerOpen] = React.useState(false);
  const [month, setMonth] = React.useState<Date | undefined>(minDate);
  const [tableVersion, setTableVersion] = React.useState(0);
  const db = usePGlite();

  const query = React.useMemo(() => {
    const dateFilter = minDate
      ? `AND date >= $${debouncedSearchQuery ? 2 : 1}::TIMESTAMPTZ`
      : "";

    if (debouncedSearchQuery) {
      return `-- version: ${tableVersion}\n
          WITH search_query AS (SELECT websearch_to_tsquery('english', $1) AS query)
          SELECT
            id, subject, author, date, in_reply_to, refs, month_file, path, nlevel(path) AS level
          FROM messages, search_query
          WHERE search @@ search_query.query ${dateFilter}
          ORDER BY ts_rank_cd(search, search_query.query) ASC
          LIMIT 100;`;
    } else {
      return `-- version: ${tableVersion}\n
          WITH messages_with_min_date AS (
            SELECT 
              id, subject, author, date, in_reply_to, refs, month_file, path, nlevel(path) AS level,
              MIN(date) OVER (PARTITION BY subject) AS min_subject_date
            FROM messages
            WHERE 1=1 ${dateFilter}
          )
          SELECT 
            id, subject, author, date, in_reply_to, refs, month_file, path, level
          FROM messages_with_min_date
          ORDER BY min_subject_date, subject, date ASC
          LIMIT 100;`;
    }
  }, [debouncedSearchQuery, minDate, tableVersion]);
  const params = React.useMemo(() => {
    const result: (string | null)[] = [];
    if (debouncedSearchQuery) {
      result.push(debouncedSearchQuery);
    }
    if (minDate) {
      // Format as ISO string for TIMESTAMPTZ, setting time to start of day
      const dateStr = format(minDate, "yyyy-MM-dd");
      result.push(`${dateStr} 00:00:00+00`);
    }
    return result;
  }, [debouncedSearchQuery, minDate]);

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
        {/* Search and Filters */}
        <div className="flex items-center gap-3 flex-wrap">
          <Input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search messages..."
            className="flex-1 min-w-[200px]"
          />
          <div className="relative flex gap-2">
            <Input
              value={dateInputValue}
              placeholder="Tomorrow or next week"
              className="bg-background pr-10 w-[200px]"
              onChange={(e) => {
                setDateInputValue(e.target.value);
                const parsedDate = parseDate(e.target.value);
                if (parsedDate) {
                  setMinDate(parsedDate);
                  setMonth(parsedDate);
                } else {
                  setMinDate(undefined);
                }
              }}
              onKeyDown={(e) => {
                if (e.key === "ArrowDown") {
                  e.preventDefault();
                  setDatePickerOpen(true);
                }
              }}
            />
            <Popover open={datePickerOpen} onOpenChange={setDatePickerOpen}>
              <PopoverTrigger asChild>
                <Button
                  variant="ghost"
                  className="absolute top-1/2 right-2 size-6 -translate-y-1/2"
                >
                  <CalendarIcon className="size-3.5" />
                  <span className="sr-only">Select date</span>
                </Button>
              </PopoverTrigger>
              <PopoverContent
                className="w-auto overflow-hidden p-0"
                align="end"
                alignOffset={-8}
                sideOffset={10}
              >
                <Calendar
                  mode="single"
                  selected={minDate}
                  captionLayout="dropdown"
                  month={month}
                  onMonthChange={setMonth}
                  onSelect={(date) => {
                    setMinDate(date);
                    setDateInputValue(date ? formatDateForDisplay(date) : "");
                    setDatePickerOpen(false);
                  }}
                />
              </PopoverContent>
            </Popover>
          </div>
          <Button onClick={handleCreateTable} variant="default">
            Create Table
          </Button>
          <Button onClick={handleDelete} variant="destructive">
            Delete All
          </Button>
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
