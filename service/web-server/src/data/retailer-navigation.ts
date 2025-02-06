import {
  ShoppingCart,
  Tag,
  Store,
  Package,
  Settings2,
  Users,
} from "lucide-react";

interface NavItem {
  title: string;
  url: string;
  icon: any;
  isActive?: boolean;
  items?: {
    title: string;
    url: string;
  }[];
}

interface Project {
  name: string;
  url: string;
  icon: any;
}

export const navMainData: NavItem[] = [
  {
    title: "Products",
    url: "#",
    icon: ShoppingCart,
    isActive: true,
    items: [
      {
        title: "New Arrivals",
        url: "#",
      },
      {
        title: "Best Sellers",
        url: "#",
      },
      {
        title: "Discounts",
        url: "#",
      },
    ],
  },
  {
    title: "Brands",
    url: "#",
    icon: Tag,
    items: [
      {
        title: "Popular Brands",
        url: "#",
      },
      {
        title: "New Brands",
        url: "#",
      },
      {
        title: "Brand Stories",
        url: "#",
      },
    ],
  },
  {
    title: "Stores",
    url: "#",
    icon: Store,
    items: [
      {
        title: "Nearby Stores",
        url: "#",
      },
      {
        title: "Store Events",
        url: "#",
      },
      {
        title: "Store Services",
        url: "#",
      },
    ],
  },
  {
    title: "Orders",
    url: "#",
    icon: Package,
    items: [
      {
        title: "Order History",
        url: "#",
      },
      {
        title: "Track Order",
        url: "#",
      },
      {
        title: "Returns",
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
        title: "Account Settings",
        url: "#",
      },
      {
        title: "Payment Methods",
        url: "#",
      },
      {
        title: "Notifications",
        url: "#",
      },
    ],
  },
];

export const projects: Project[] = [
  {
    name: "Customer Engagement",
    url: "#",
    icon: Users,
  },
  {
    name: "Inventory Management",
    url: "#",
    icon: Package,
  },
  {
    name: "Store Expansion",
    url: "#",
    icon: Store,
  },
];
