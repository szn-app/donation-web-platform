import { createContext, Dispatch, PropsWithChildren, useState } from "react";

type GlobalContextState = [any[], Dispatch<React.SetStateAction<any[]>>];

const GlobalContext = createContext<GlobalContextState>([[], () => {}]);

export function GlobalProvider({ children }: PropsWithChildren) {
  const globalHook = useState<any[]>([]);

  return (
    <GlobalContext.Provider value={globalHook}>
      {children}
    </GlobalContext.Provider>
  );
}
