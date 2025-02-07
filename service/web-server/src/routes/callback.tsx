import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useAuth } from "react-oidc-context";
import { useEffect } from "react";

// TODO: improve: check https://github.com/authts/react-oidc-context?tab=readme-ov-file
export const Route = createFileRoute("/callback")({
  component,
});

export function component() {
  const auth = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!auth.isLoading && !auth.error) {
      navigate({ to: "/" });
    }
  }, [auth.isLoading, auth.error, navigate]);

  return <div>Loading...</div>;
}
