import * as React from "react";

import { NavMain, NavItem } from "@/components/nav-main";
import { NavProjects, Project } from "@/components/nav-projects";
import { NavUser, type User } from "@/components/nav-user";
import { TeamSwitcher, type Team } from "@/components/team-switcher";
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarRail,
} from "@/components/ui/sidebar";

export type { NavItem };
export type { Project };
export type { Team };
export type { User };

export interface AppSidebarProps extends React.ComponentProps<typeof Sidebar> {
  user: User;
  teams: Team[];
  navItems: NavItem[];
  projects: Project[];
}

export function AppSidebar({
  user,
  teams,
  navItems,
  projects,
  ...props
}: AppSidebarProps) {
  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <TeamSwitcher teams={teams} />
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={navItems} />
        <NavProjects projects={projects} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser user={user} />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  );
}
