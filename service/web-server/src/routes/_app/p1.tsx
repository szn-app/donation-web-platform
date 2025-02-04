import { createFileRoute, Link } from "@tanstack/react-router";

export const Route = createFileRoute("/_app/p1")({
  component: RouteComponent,
});

const str: string = "/product";

function RouteComponent() {
  return (
    <div>
      <Link to={str}> Hello "/p1"! </Link>
    </div>
  );
}
