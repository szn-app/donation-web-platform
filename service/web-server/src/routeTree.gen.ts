/* eslint-disable */

// @ts-nocheck

// noinspection JSUnusedGlobalSymbols

// This file was automatically generated by TanStack Router.
// You should NOT make any changes in this file as it will be overwritten.
// Additionally, you should also exclude this file from your linter and/or formatter to prevent it from being checked or modified.

// Import Routes

import { Route as rootRoute } from './routes/__root'
import { Route as AppImport } from './routes/_app'
import { Route as AppIndexImport } from './routes/_app/index'
import { Route as AppProductImport } from './routes/_app/product'
import { Route as AppP2Import } from './routes/_app/p2'
import { Route as AppP1Import } from './routes/_app/p1'

// Create/Update Routes

const AppRoute = AppImport.update({
  id: '/_app',
  getParentRoute: () => rootRoute,
} as any)

const AppIndexRoute = AppIndexImport.update({
  id: '/',
  path: '/',
  getParentRoute: () => AppRoute,
} as any)

const AppProductRoute = AppProductImport.update({
  id: '/product',
  path: '/product',
  getParentRoute: () => AppRoute,
} as any)

const AppP2Route = AppP2Import.update({
  id: '/p2',
  path: '/p2',
  getParentRoute: () => AppRoute,
} as any)

const AppP1Route = AppP1Import.update({
  id: '/p1',
  path: '/p1',
  getParentRoute: () => AppRoute,
} as any)

// Populate the FileRoutesByPath interface

declare module '@tanstack/react-router' {
  interface FileRoutesByPath {
    '/_app': {
      id: '/_app'
      path: ''
      fullPath: ''
      preLoaderRoute: typeof AppImport
      parentRoute: typeof rootRoute
    }
    '/_app/p1': {
      id: '/_app/p1'
      path: '/p1'
      fullPath: '/p1'
      preLoaderRoute: typeof AppP1Import
      parentRoute: typeof AppImport
    }
    '/_app/p2': {
      id: '/_app/p2'
      path: '/p2'
      fullPath: '/p2'
      preLoaderRoute: typeof AppP2Import
      parentRoute: typeof AppImport
    }
    '/_app/product': {
      id: '/_app/product'
      path: '/product'
      fullPath: '/product'
      preLoaderRoute: typeof AppProductImport
      parentRoute: typeof AppImport
    }
    '/_app/': {
      id: '/_app/'
      path: '/'
      fullPath: '/'
      preLoaderRoute: typeof AppIndexImport
      parentRoute: typeof AppImport
    }
  }
}

// Create and export the route tree

interface AppRouteChildren {
  AppP1Route: typeof AppP1Route
  AppP2Route: typeof AppP2Route
  AppProductRoute: typeof AppProductRoute
  AppIndexRoute: typeof AppIndexRoute
}

const AppRouteChildren: AppRouteChildren = {
  AppP1Route: AppP1Route,
  AppP2Route: AppP2Route,
  AppProductRoute: AppProductRoute,
  AppIndexRoute: AppIndexRoute,
}

const AppRouteWithChildren = AppRoute._addFileChildren(AppRouteChildren)

export interface FileRoutesByFullPath {
  '': typeof AppRouteWithChildren
  '/p1': typeof AppP1Route
  '/p2': typeof AppP2Route
  '/product': typeof AppProductRoute
  '/': typeof AppIndexRoute
}

export interface FileRoutesByTo {
  '/p1': typeof AppP1Route
  '/p2': typeof AppP2Route
  '/product': typeof AppProductRoute
  '/': typeof AppIndexRoute
}

export interface FileRoutesById {
  __root__: typeof rootRoute
  '/_app': typeof AppRouteWithChildren
  '/_app/p1': typeof AppP1Route
  '/_app/p2': typeof AppP2Route
  '/_app/product': typeof AppProductRoute
  '/_app/': typeof AppIndexRoute
}

export interface FileRouteTypes {
  fileRoutesByFullPath: FileRoutesByFullPath
  fullPaths: '' | '/p1' | '/p2' | '/product' | '/'
  fileRoutesByTo: FileRoutesByTo
  to: '/p1' | '/p2' | '/product' | '/'
  id:
    | '__root__'
    | '/_app'
    | '/_app/p1'
    | '/_app/p2'
    | '/_app/product'
    | '/_app/'
  fileRoutesById: FileRoutesById
}

export interface RootRouteChildren {
  AppRoute: typeof AppRouteWithChildren
}

const rootRouteChildren: RootRouteChildren = {
  AppRoute: AppRouteWithChildren,
}

export const routeTree = rootRoute
  ._addFileChildren(rootRouteChildren)
  ._addFileTypes<FileRouteTypes>()

/* ROUTE_MANIFEST_START
{
  "routes": {
    "__root__": {
      "filePath": "__root.tsx",
      "children": [
        "/_app"
      ]
    },
    "/_app": {
      "filePath": "_app.tsx",
      "children": [
        "/_app/p1",
        "/_app/p2",
        "/_app/product",
        "/_app/"
      ]
    },
    "/_app/p1": {
      "filePath": "_app/p1.tsx",
      "parent": "/_app"
    },
    "/_app/p2": {
      "filePath": "_app/p2.tsx",
      "parent": "/_app"
    },
    "/_app/product": {
      "filePath": "_app/product.tsx",
      "parent": "/_app"
    },
    "/_app/": {
      "filePath": "_app/index.tsx",
      "parent": "/_app"
    }
  }
}
ROUTE_MANIFEST_END */
