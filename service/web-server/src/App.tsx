import "./.css";
import { StrictMode } from "react";
import ReactDOM from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider, createRouter } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";

const router = createRouter({ routeTree });
const query_client = new QueryClient();

function App() {
  return (
    <StrictMode>
      <QueryClientProvider client={query_client}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    </StrictMode>
  );
}

const root = ReactDOM.createRoot(
  document.getElementById("root") as HTMLElement,
);
root.render(<App />);
