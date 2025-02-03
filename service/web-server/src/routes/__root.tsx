import * as React from "react";
import { Outlet, createRootRoute } from "@tanstack/react-router";
import { TanStackRouterDevtools } from "@tanstack/router-devtools";
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";
import { NextUIProvider } from "@nextui-org/react";
import { GlobalProvider } from "../context/GlobalContext";
import { useState } from "react";

export const Route = createRootRoute({
  component: function () {
    return (
      <>
        <GlobalProvider>
          <NextUIProvider>
            <Outlet />
          </NextUIProvider>
        </GlobalProvider>

        <ReactQueryDevtools />
        <TanStackRouterDevtools />
      </>
    );
  },
});
