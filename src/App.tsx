import React from "react";
import { PGliteProvider } from "@electric-sql/pglite-react";
import { Messages } from "./Messages";

interface AppProps {
  pglite: any; // PGliteWorker instance
  searchQuery?: string;
}

export const App: React.FC<AppProps> = ({ pglite, searchQuery }) => {
  return (
    <PGliteProvider db={pglite}>
      <Messages searchQuery={searchQuery} />
    </PGliteProvider>
  );
};

