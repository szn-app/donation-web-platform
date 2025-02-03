import { createLazyFileRoute } from "@tanstack/react-router";
import Layout from "@/components/Layout";

export const Route = createLazyFileRoute("/")({
  component: Index,
});

function Index() {
  return <Layout key1={5}></Layout>;
}
