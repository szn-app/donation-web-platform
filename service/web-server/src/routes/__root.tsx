import * as React from "react";
import { Outlet, createRootRoute } from "@tanstack/react-router";
import { TanStackRouterDevtools } from "@tanstack/router-devtools";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { NextUIProvider } from "@nextui-org/react";
import { GlobalContext } from "../context/GlobalContext";
import { useState } from "react";

export const Route = createRootRoute({
  component: function () {
    const globalHook = useState([]);

    return (
      <>
        <GlobalContext value={globalHook}>
          <NextUIProvider>
            <Outlet />
          </NextUIProvider>
        </GlobalContext>

        <ReactQueryDevtools />
        <TanStackRouterDevtools />
      </>
    );
  },
});
