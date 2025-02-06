import { SidebarContent as MarketSidebarContent } from "@/routes/_app/market.lazy";
import { SidebarContent as RetailerSidebarContent } from "@/routes/_app/retailer.lazy";
import { SidebarContent as LuxurySidebarContent } from "@/routes/_app/luxury.lazy";
import { SidebarContent as DonationSidebarContent } from "@/routes/_app/donation.lazy";
import { HeartHandshake, Store, Gem, ShoppingBag } from "lucide-react";
import { Section } from "@/components/section-switcher";
import { User } from "@/components/nav-user";

export const sections: Section[] = [
  {
    name: "In-Kind Donations",
    logo: HeartHandshake,
    plan: "Free stuff",
    url: "/donation",
    sidebarContent: DonationSidebarContent,
  },
  {
    name: "Buyer-Seller Market",
    logo: ShoppingBag,
    plan: "Pre-owned / Used",
    url: "/market",
    sidebarContent: MarketSidebarContent,
  },
  {
    name: "Retailers Marketplace",
    logo: Store,
    plan: "Multi-Vendor",
    url: "/retailer",
    sidebarContent: RetailerSidebarContent,
  },
  {
    name: "Luxury Collection",
    logo: Gem,
    plan: "Curated. Exquisite. Rare.",
    url: "/luxury",
    sidebarContent: LuxurySidebarContent,
  },
];

// example user
export const user_example: User = {
  name: "Mr./Mrs.",
  email: "me@gmail.com",
  avatar: "/avatar.svg",
};
