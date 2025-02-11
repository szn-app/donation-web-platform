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
    const exchangeCode = async () => {
      const urlParams = new URLSearchParams(window.location.search);
      const code = urlParams.get('code');
      
      if (code) {
        try {
          const response = await fetch('/api/oauth2_token', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              code,
              redirect_uri: window.location.origin + '/callback',
            }),
          });

          if (response.ok) {
            const token = await response.json();
            // TODO: store token or handle it according to your needs
            navigate({ to: "/" });
          }
        } catch (error) {
          console.error('Token exchange failed:', error);
        }
      }
    };

    if (!auth.isLoading) {
      exchangeCode();
    }
  }, [auth.isLoading, navigate]);

  return <div>Processing authentication...</div>;
}
