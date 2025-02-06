import { ShoppingBag, Tag, Truck, Users, Wallet } from "lucide-react";

export const navMainData = [
  {
    title: "Marketplace",
    url: "#",
    icon: ShoppingBag,
    isActive: true,
    items: [
      {
        title: "Browse",
        url: "#",
      },
      {
        title: "Categories",
        url: "#",
      },
      {
        title: "Deals",
        url: "#",
      },
    ],
  },
  {
    title: "My Store",
    url: "#",
    icon: Tag,
    items: [
      {
        title: "Products",
        url: "#",
      },
      {
        title: "Orders",
        url: "#",
      },
      {
        title: "Analytics",
        url: "#",
      },
    ],
  },
];

export const projects = [
  {
    name: "Transactions",
    url: "#",
    icon: Wallet,
  },
  {
    name: "Shipping",
    url: "#",
    icon: Truck,
  },
];
