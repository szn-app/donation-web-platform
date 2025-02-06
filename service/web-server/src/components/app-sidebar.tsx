import * as React from "react";
import { useContext, useEffect } from "react";

import { NavUser, type User } from "@/components/nav-user";
import { SectionSwitcher, type Section } from "@/components/section-switcher";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarRail,
} from "@/components/ui/sidebar";
import { SectionContext } from "@/context/SectionContext";

import { Button } from "@/components/ui/button";
import { LogIn, User2 } from "lucide-react";

export type { Section };
export type { User };

export interface AppSidebarProps extends React.ComponentProps<typeof Sidebar> {
  user: User | null;
  sections: Section[];
}

export function AppSidebar({
  user,
  sections,
  children,
  ...props
}: React.PropsWithChildren<AppSidebarProps>) {
  const { activeSection } = useContext(SectionContext);

  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <SectionSwitcher sections={sections} />
      </SidebarHeader>
      <SidebarContent>
        {activeSection && <activeSection.sidebarContent />}
      </SidebarContent>
      <SidebarFooter>
        {user ? (
          <NavUser user={user} />
        ) : (
          <SidebarMenu>
            <SidebarMenuItem>
              <a
                href="https://auth.wosoom.com/login"
                target="_blank"
                rel="noopener"
              >
                <SidebarMenuButton tooltip="Log in" variant="outline_colored">
                  <LogIn />
                  <span className="whitespace-nowrap">Log in</span>
                  <User2 className="ml-auto" />
                </SidebarMenuButton>
              </a>
            </SidebarMenuItem>
          </SidebarMenu>
        )}
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  );
}
