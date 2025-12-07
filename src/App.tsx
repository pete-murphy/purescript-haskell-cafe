import React from "react";
import { PGliteProvider } from "@electric-sql/pglite-react";
import { Messages } from "./Messages";

interface AppProps {
  pglite: any; // PGliteWorker instance
}

export const App: React.FC<AppProps> = ({ pglite }) => {
  return (
    <PGliteProvider db={pglite}>
      <Messages />
    </PGliteProvider>
  );
};
