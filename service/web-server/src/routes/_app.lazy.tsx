import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";
import { Outlet, createLazyFileRoute } from "@tanstack/react-router";
import { Separator } from "@/components/ui/separator";
import { SidebarTrigger } from "@/components/ui/sidebar";
import { SectionProvider } from "@/context/SectionContext";
import { BreadcrumbListComponent } from "@/components/breadcrumb-list";
import { sections } from "@/data/sections";
import { UserProvider } from "@/context/UserContext";

export const Route = createLazyFileRoute("/_app")({
  component,
  notFoundComponent: () => {
    return <h1>Not Found! from _app</h1>;
  },
});

function component() {
  return (
    <UserProvider>
      <SectionProvider sections={sections}>
        <SidebarProvider>
          <AppSidebar />
          <SidebarInset>
            <header className="flex h-16 shrink-0 items-center gap-2 transition-[width,height] ease-linear group-has-[[data-collapsible=icon]]/sidebar-wrapper:h-12">
              <div className="flex items-center gap-2 px-4">
                <SidebarTrigger className="-ml-1" />
                <Separator orientation="vertical" className="mr-2 h-4" />
                <BreadcrumbListComponent />
              </div>
            </header>
            <Outlet />
          </SidebarInset>
        </SidebarProvider>
      </SectionProvider>
    </UserProvider>
  );
}
