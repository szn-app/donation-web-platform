import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/past")({
  component: RouteComponent,
});

function RouteComponent() {
  return <div>Hello "/past"!</div>;
}
