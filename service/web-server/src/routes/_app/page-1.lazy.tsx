import { useEffect, useState } from "react";
import { createLazyFileRoute } from "@tanstack/react-router";

export const Route = createLazyFileRoute("/_app/page-1")({
  component: RouteComponent,
  notFoundComponent: () => {
    return <h1>Not Found! from _app/page-1</h1>;
  },
});

function RouteComponent() {
  return (
    <>
      <div className="flex flex-1 flex-col gap-4 p-4 pt-0">
        <div className="grid auto-rows-min gap-4 md:grid-cols-3">
          <div className="aspect-video rounded-xl bg-zinc-100/50 dark:bg-zinc-800/50" />
          <div className="aspect-video rounded-xl bg-zinc-100/50 dark:bg-zinc-800/50" />
          <div className="aspect-video rounded-xl bg-zinc-100/50 dark:bg-zinc-800/50" />
        </div>
        <div className="min-h-[100vh] flex-1 rounded-xl bg-zinc-100/50 dark:bg-zinc-800/50 md:min-h-min" />
      </div>
    </>
  );
}
