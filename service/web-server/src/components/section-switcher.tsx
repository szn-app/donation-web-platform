import React, { Fragment, useContext, useEffect } from "react";
import { useMatchRoute, useNavigate, useRouter } from "@tanstack/react-router";

import { ChevronsUpDown, Plus } from "lucide-react";

import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuShortcut,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from "@/components/ui/sidebar";
import { SectionContext } from "@/context/SectionContext";

export interface Section {
  name: string;
  logo: React.ComponentType<React.SVGProps<SVGSVGElement>>;
  plan: string;
  url: string;
  sidebarContent: React.ComponentType;
}

export function SectionSwitcher({ sections }: { sections: Section[] }) {
  const { isMobile, setOpen } = useSidebar();
  const { activeSection, setActiveSection } = useContext(SectionContext);

  const navigate = useNavigate();
  const router = useRouter();
  const matchRoute = useMatchRoute();

  useEffect(() => {
    const currentUrl = router.state.location.pathname;
    const currentSection = sections.find(
      (section) => !!matchRoute({ to: section.url, fuzzy: true }),
    );
    if (currentSection) {
      setActiveSection(currentSection);
    }
  }, []);

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <SidebarMenuButton
              size="lg"
              className="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
            >
              <div className="aspect-square flex items-center justify-center rounded-lg bg-sidebar-primary text-sidebar-primary-foreground">
                <activeSection.logo className="size-8" />
              </div>
              <div className="grid flex-1 text-left text-sm leading-tight">
                <span className="truncate font-semibold">
                  {activeSection.name}
                </span>
                <span className="truncate text-xs">{activeSection.plan}</span>
              </div>
              <ChevronsUpDown className="ml-auto" />
            </SidebarMenuButton>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            className="w-[--radix-dropdown-menu-trigger-width] min-w-56 rounded-lg"
            align="start"
            side={isMobile ? "bottom" : "right"}
            sideOffset={4}
          >
            <DropdownMenuLabel className="text-xs text-zinc-500 dark:text-zinc-400">
              Marketplaces
            </DropdownMenuLabel>
            {sections.map((section, index) => (
              <Fragment key={section.name}>
                <DropdownMenuItem
                  onClick={() => {
                    setActiveSection(section);
                    navigate({ to: section.url });
                    setOpen(false);
                  }}
                  className="gap-2 p-2"
                >
                  <div className="flex size-6 items-center justify-center rounded-sm border">
                    <section.logo className="size-4 shrink-0" />
                  </div>
                  {section.name}
                  {/* <DropdownMenuShortcut>⌘{index + 1}</DropdownMenuShortcut> */}
                </DropdownMenuItem>
                {index === 0 || index === 2 ? <DropdownMenuSeparator /> : null}
              </Fragment>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      </SidebarMenuItem>
    </SidebarMenu>
  );
}
