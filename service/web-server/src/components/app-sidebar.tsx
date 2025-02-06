import * as React from "react";
import { useContext, useEffect } from "react";

import { NavUser, type User } from "@/components/nav-user";
import { SectionSwitcher, type Section } from "@/components/section-switcher";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarRail,
} from "@/components/ui/sidebar";
import { SectionContext } from "@/context/SectionContext";

export type { Section };
export type { User };

export interface AppSidebarProps extends React.ComponentProps<typeof Sidebar> {
  user: User;
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
        <NavUser user={user} />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  );
}
