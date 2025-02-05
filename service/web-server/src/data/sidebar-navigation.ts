import { Team, NavItem, Project, User } from "@/components/app-sidebar";
import {
  AudioWaveform,
  BookOpen,
  Bot,
  Command,
  Frame,
  Flower2,
  Map,
  PieChart,
  Settings2,
  SquareTerminal,
  HeartHandshake,
  Store,
  Gem,
  ShoppingBag,
} from "lucide-react";

export const user: User = {
  name: "shadcn",
  email: "m@example.com",
  avatar: "/avatars/shadcn.jpg",
};

export const teams: Team[] = [
  {
    name: "In-Kind Donations",
    logo: HeartHandshake,
    plan: "Free stuff",
    url: "/donation",
  },
  {
    name: "Buy-Sell Market",
    logo: ShoppingBag,
    plan: "Pre-owned / Used",
    url: "/market",
  },
  {
    name: "Retailers Marketplace",
    logo: Store,
    plan: "Multi-Vendor",
    url: "/retailer",
  },
  {
    name: "Luxury Collection",
    logo: Gem,
    plan: "Curated. Exquisite. Rare.",
    url: "/luxury",
  },
];

export const navMain: NavItem[] = [
  {
    title: "Playground",
    url: "#",
    icon: SquareTerminal,
    isActive: true,
    items: [
      {
        title: "History",
        url: "#",
      },
      {
        title: "Starred",
        url: "#",
      },
      {
        title: "Settings",
        url: "#",
      },
    ],
  },
  {
    title: "Models",
    url: "#",
    icon: Bot,
    items: [
      {
        title: "Genesis",
        url: "#",
      },
      {
        title: "Explorer",
        url: "#",
      },
      {
        title: "Quantum",
        url: "#",
      },
    ],
  },
  {
    title: "Documentation",
    url: "#",
    icon: BookOpen,
    items: [
      {
        title: "Introduction",
        url: "#",
      },
      {
        title: "Get Started",
        url: "#",
      },
      {
        title: "Tutorials",
        url: "#",
      },
      {
        title: "Changelog",
        url: "#",
      },
    ],
  },
  {
    title: "Settings",
    url: "#",
    icon: Settings2,
    items: [
      {
        title: "General",
        url: "#",
      },
      {
        title: "Team",
        url: "#",
      },
      {
        title: "Billing",
        url: "#",
      },
      {
        title: "Limits",
        url: "#",
      },
    ],
  },
];

export const projects: Project[] = [
  {
    name: "Design Engineering",
    url: "#",
    icon: Frame,
  },
  {
    name: "Sales & Marketing",
    url: "#",
    icon: PieChart,
  },
  {
    name: "Travel",
    url: "#",
    icon: Map,
  },
];
