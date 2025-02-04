import * as React from "react";
import { Outlet, createRootRoute } from "@tanstack/react-router";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { NextUIProvider } from "@nextui-org/react";
import { GlobalProvider } from "../context/GlobalContext";
import { Suspense, useState } from "react";
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";

const TanStackRouterDevtools =
  process.env.NODE_ENV === "production"
    ? () => null // Render nothing in production
    : React.lazy(() =>
        // Lazy load in development
        import("@tanstack/router-devtools").then((res) => ({
          default: res.TanStackRouterDevtools,
          // For Embedded Mode
          // default: res.TanStackRouterDevtoolsPanel
        })),
      );

export const Route = createRootRoute({
  component: () => (
    <>
      <GlobalProvider>
        <NextUIProvider>
          <Outlet />
        </NextUIProvider>
      </GlobalProvider>
      <ReactQueryDevtools />
      <Suspense>
        <TanStackRouterDevtools />
      </Suspense>
    </>
  ),
});
