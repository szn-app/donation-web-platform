import React, { Suspense, useState } from "react";
import { Outlet, createRootRoute } from "@tanstack/react-router";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { GlobalProvider } from "../contexts/GlobalContext";
import { HeroUIProvider } from "@heroui/react";
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
        <HeroUIProvider>
          <Outlet />
        </HeroUIProvider>
      </GlobalProvider>
      <ReactQueryDevtools />
      <Suspense>
        <TanStackRouterDevtools />
      </Suspense>
    </>
  ),
});
