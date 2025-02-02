import "./App.css";
import React from "react";
import { AppSidebar } from "@/components/app-sidebar";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";
import { Separator } from "@/components/ui/separator";
import {
  SidebarInset,
  SidebarProvider,
  SidebarTrigger,
} from "@/components/ui/sidebar";
import { DataTableDemo } from "@/app/table";
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerBody,
  DrawerFooter,
  Button,
  useDisclosure,
} from "@nextui-org/react";

import { createLazyFileRoute, Link } from "@tanstack/react-router";

export const Route = createLazyFileRoute("/")({
  component: App,
});

import Example from "@/components/with_avatars_and_multi_line_content";

import Pizza from "@/components/Pizza";
import Order from "@/components/Order";

function App() {
  const { isOpen, onOpen, onOpenChange } = useDisclosure();

  return (
    <>
      <SidebarProvider>
        <AppSidebar />
        <SidebarInset>
          <header className="flex h-16 shrink-0 items-center gap-2 transition-[width,height] ease-linear group-has-[[data-collapsible=icon]]/sidebar-wrapper:h-12">
            <div className="flex items-center gap-2 px-4">
              <SidebarTrigger className="-ml-1" />
              <Separator orientation="vertical" className="mr-2 h-4" />
              <Breadcrumb>
                <BreadcrumbList>
                  <BreadcrumbItem className="hidden md:block">
                    <Link to="/order">order</Link>
                    <BreadcrumbLink href="#">
                      Building Your Application
                    </BreadcrumbLink>
                  </BreadcrumbItem>
                  <BreadcrumbSeparator className="hidden md:block" />
                  <BreadcrumbItem>
                    <BreadcrumbPage>Data Fetching</BreadcrumbPage>
                  </BreadcrumbItem>
                </BreadcrumbList>
              </Breadcrumb>
            </div>
          </header>
          <div className="flex flex-1 flex-col gap-4 p-4 pt-0">
            <Order></Order>
            <DataTableDemo></DataTableDemo>

            <Pizza type="mozarella"></Pizza>
            <Pizza type="mozarell3"></Pizza>
            <Pizza type="mozarella2"></Pizza>

            <div className="grid auto-rows-min gap-4 md:grid-cols-3">
              <div className="aspect-video rounded-xl bg-muted/50" />
              <div className="aspect-video animate-pulse content-center rounded-xl bg-muted/50 text-justify text-3xl">
                ❤️ Rima wE LoVE yOU ❤️‍🔥
              </div>
              <div className="aspect-video rounded-xl bg-muted/50" />
            </div>
            <div className="min-h-[100vh] flex-1 rounded-xl bg-muted/50 md:min-h-min">
              <Button>Press me</Button>
              <Button onPress={onOpen}>Open Drawer</Button>
              <Drawer isOpen={isOpen} onOpenChange={onOpenChange}>
                <DrawerContent>
                  {(onClose) => (
                    <>
                      <DrawerHeader className="flex flex-col gap-1">
                        Drawer Title
                      </DrawerHeader>
                      <DrawerBody>
                        <p>
                          Lorem ipsum dolor sit amet, consectetur adipiscing
                          elit. Nullam pulvinar risus non risus hendrerit
                          venenatis. Pellentesque sit amet hendrerit risus, sed
                          porttitor quam.
                        </p>
                        <p>
                          Lorem ipsum dolor sit amet, consectetur adipiscing
                          elit. Nullam pulvinar risus non risus hendrerit
                          venenatis. Pellentesque sit amet hendrerit risus, sed
                          porttitor quam.
                        </p>
                        <p>
                          Magna exercitation reprehenderit magna aute tempor
                          cupidatat consequat elit dolor adipisicing. Mollit
                          dolor eiusmod sunt ex incididunt cillum quis. Velit
                          duis sit officia eiusmod Lorem aliqua enim laboris do
                          dolor eiusmod. Et mollit incididunt nisi consectetur
                          esse laborum eiusmod pariatur proident Lorem eiusmod
                          et. Culpa deserunt nostrud ad veniam.
                        </p>
                      </DrawerBody>
                      <DrawerFooter>
                        <Button
                          color="danger"
                          variant="light"
                          onPress={onClose}
                        >
                          Close
                        </Button>
                        <Button color="primary" onPress={onClose}>
                          Action
                        </Button>
                      </DrawerFooter>
                    </>
                  )}
                </DrawerContent>
              </Drawer>

              <Example></Example>
            </div>
          </div>
        </SidebarInset>
      </SidebarProvider>
    </>
  );
}
