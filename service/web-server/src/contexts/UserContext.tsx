import React, { createContext, useState, PropsWithChildren } from "react";
import { User } from "@/components/app-sidebar";

export type { User };

interface UserContextType {
  user: User | null;
  setUser: React.Dispatch<React.SetStateAction<User | null>>;
}

export const UserContext = createContext<UserContextType>({
  user: null,
  setUser: () => {},
});

export function UserProvider({ children }: PropsWithChildren<{}>) {
  const [user, setUser] = useState<User | null>(null);

  return (
    <UserContext.Provider value={{ user, setUser }}>
      {children}
    </UserContext.Provider>
  );
}
