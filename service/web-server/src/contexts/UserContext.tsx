import React, { createContext, useState, PropsWithChildren } from "react";
import { User } from "@/components/app-sidebar";
import { AuthProviderProps, AuthProvider } from "react-oidc-context";
import { v4 as uuidv4 } from "uuid";

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

// NOTE: implicit OIDC config added: https://auth.wosoom.com/authorize/.well-known/openid-configuration
// https://auth.wosoom.com/authorize/.well-known/jwks.json
// https://github.com/authts/oidc-client-ts/blob/main/docs/protocols/authorization-code-grant-with-pkce.md
export const oidcConfig: AuthProviderProps = {
  authority: import.meta.env.VITE_AUTHORIZATION_URL, // Ory Hydra server URL
  client_id: "frontend-client", // OIDC client ID
  redirect_uri: `${import.meta.env.VITE_APP_URL}/callback`, // redirect URI
  response_type: "code", // NOTE: "code id_token" response type doesn't seem to be supported by react-oidc-context (thus id_token can be fetched from userinfo endpoint with additional request instead)
  scope: "offline_access openid",
  loadUserInfo: true,
  automaticSilentRenew: true,
  //   silent_redirect_uri: "https://wosoom.com/silent-renew",
  post_logout_redirect_uri: `${import.meta.env.VITE_APP_URL}/callback`,
  disablePKCE: false,
  // customize token endpoint to pass code for app backend exchange
  metadata: {
    authorization_endpoint: `${import.meta.env.VITE_AUTHORIZATION_URL}/oauth2/auth`, // Authorization endpoint
    // token_endpoint: "https://auth.wosoom.com/authorize/oauth2/token", // Token endpoint
    token_endpoint: `${import.meta.env.VITE_APP_URL}/token_exchange`, // custom Token endpoint
    userinfo_endpoint: `${import.meta.env.VITE_AUTHORIZATION_URL}/userinfo`, // UserInfo endpoint
    end_session_endpoint: `${import.meta.env.VITE_AUTHORIZATION_URL}/oauth2/sessions/logout`, // End session endpoint
    jwks_uri: `${import.meta.env.VITE_AUTHORIZATION_URL}/.well-known/jwks.json`, // JWKS endpoint
    issuer: `${import.meta.env.VITE_AUTHORIZATION_URL}/`, // Issuer URL
  },
  extraQueryParams: {},
};

export function AuthContextProvider({ children }: PropsWithChildren<{}>) {
  return <AuthProvider {...oidcConfig}>{children}</AuthProvider>;
}
