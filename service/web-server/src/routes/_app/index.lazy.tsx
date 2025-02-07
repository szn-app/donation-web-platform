import { useEffect, useState } from "react";
import { createLazyFileRoute } from "@tanstack/react-router";
import { useNavigate } from "@tanstack/react-router";
import { useAuth } from "react-oidc-context";

export const Route = createLazyFileRoute("/_app/")({
  component,
});

function component() {
  const navigate = useNavigate();
  const auth = useAuth();

  useEffect(() => {
    // navigate({ to: "/donation" });
  }, []);

  return (
    <div>
      <h1>Welcome to the Home Page</h1>
      {auth.isAuthenticated ? (
        <button onClick={() => auth.signoutRedirect()}>Logout</button>
      ) : (
        <button onClick={() => auth.signinRedirect()}>Login</button>
      )}
    </div>
  );
}
