import { createLazyFileRoute } from "@tanstack/react-router";
import Layout from "@/components/Layout";

export const Route = createLazyFileRoute("/")({
  component: Layout,
});
