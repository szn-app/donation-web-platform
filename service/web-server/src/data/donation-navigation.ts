import {
  BookOpen,
  Gift,
  HeartHandshake,
  History,
  Settings2,
} from "lucide-react";

export const navMainData = [
  {
    title: "Donation Center",
    url: "#",
    icon: HeartHandshake,
    isActive: true,
    items: [
      {
        title: "Available Items",
        url: "#",
      },
      {
        title: "Request Item",
        url: "#",
      },
      {
        title: "Donation History",
        url: "#",
      },
    ],
  },
  {
    title: "My Donations",
    url: "#",
    icon: Gift,
    items: [
      {
        title: "Active",
        url: "#",
      },
      {
        title: "Completed",
        url: "#",
      },
      {
        title: "Reserved",
        url: "#",
      },
    ],
  },
  {
    title: "History",
    url: "#",
    icon: History,
    items: [
      {
        title: "Given",
        url: "#",
      },
      {
        title: "Received",
        url: "#",
      },
    ],
  },
];

export const projects = [
  {
    name: "Donation Guidelines",
    url: "#",
    icon: BookOpen,
  },
  {
    name: "Preferences",
    url: "#",
    icon: Settings2,
  },
];
