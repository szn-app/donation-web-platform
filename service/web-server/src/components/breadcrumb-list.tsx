import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";
import { Link } from "@tanstack/react-router";
import React from "react";

export interface BreadcrumbItem {
  label: string;
  link?: string;
}

interface BreadcrumbProps {
  items: BreadcrumbItem[];
}

export function BreadcrumbListComponent({ items }: BreadcrumbProps) {
  return (
    <Breadcrumb>
      <BreadcrumbList>
        {items.map((item, index) => (
          <React.Fragment key={index}>
            <BreadcrumbItem className={index === 0 ? "hidden md:block" : ""}>
              {item.link ? (
                <BreadcrumbLink asChild>
                  <Link to={item.link}>{item.label}</Link>
                </BreadcrumbLink>
              ) : (
                <BreadcrumbPage>{item.label}</BreadcrumbPage>
              )}
            </BreadcrumbItem>
            {index < items.length - 1 && (
              <BreadcrumbSeparator
                className={index === 0 ? "hidden md:block" : ""}
              />
            )}
          </React.Fragment>
        ))}
      </BreadcrumbList>
    </Breadcrumb>
  );
}

// genereate breadcrumbs using pathname
export function generateBreadcrumbs(pathname: string): BreadcrumbItem[] {
  // Remove leading and trailing slashes
  const cleanPath = pathname.replace(/^\/+|\/+$/g, "");

  if (!cleanPath) {
    return [
      // { label: "Home", link: "/" } // default
    ];
  }

  const segments = cleanPath.split("/");

  return [
    // { label: "Home", link: "/" },
    ...segments.map((segment, index) => {
      // Build the path up to this point
      const path = `/${segments.slice(0, index + 1).join("/")}`;

      // Capitalize and clean up the segment name
      const label = segment
        .split("-")
        .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
        .join(" ");

      // Last item doesn't get a link
      return index === segments.length - 1 ? { label } : { label, link: path };
    }),
  ];
}
