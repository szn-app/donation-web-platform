import "./.css";
import { StrictMode } from "react";
import ReactDOM from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider, createRouter } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";
import NotFoundGlobal from "./app/NotFoundGlobal";
import { UserProvider } from "./contexts/UserContext";

const router = createRouter({
  routeTree,
  defaultNotFoundComponent: () => {
    return <NotFoundGlobal />;
  },
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}

const query_client = new QueryClient();

const rootElement = (document.getElementById("root") as HTMLElement)!;
if (!rootElement.innerHTML) {
  const root = ReactDOM.createRoot(rootElement);
  root.render(
    <StrictMode>
      <UserProvider>
        <QueryClientProvider client={query_client}>
          <RouterProvider router={router} />
        </QueryClientProvider>
      </UserProvider>
    </StrictMode>,
  );
}
