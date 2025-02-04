import { createFileRoute, Link } from "@tanstack/react-router";

export const Route = createFileRoute("/_app/p2")({
  component: RouteComponent,
});

function RouteComponent() {
  return (
    <div>
      <Link to="/p1">Hello "/p2"!</Link>
    </div>
  );
}
