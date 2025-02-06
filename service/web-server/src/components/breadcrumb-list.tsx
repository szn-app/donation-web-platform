import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";
import { SectionContext } from "@/context/SectionContext";
import { Link, useRouter } from "@tanstack/react-router";
import { useContext, Fragment } from "react";
import { useEffect, useState, createContext } from "react";

export interface BreadcrumbItem {
  label: string;
  link?: string;
}

export function BreadcrumbListComponent() {
  const router = useRouter();

  const [pathLinks, setPathLinks] = useState<BreadcrumbItem[]>([]);
  const { activeSection } = useContext(SectionContext);

  useEffect(() => {
    setPathLinks(generateBreadcrumbs(router.state.location.pathname));
  }, [activeSection, router.state.location]);

  return (
    <Breadcrumb>
      <BreadcrumbList>
        {pathLinks.map((item, index) => (
          <Fragment key={index}>
            <BreadcrumbItem className={index === 0 ? "hidden md:block" : ""}>
              {item.link ? (
                <BreadcrumbLink asChild>
                  <Link to={item.link}>{item.label}</Link>
                </BreadcrumbLink>
              ) : (
                <BreadcrumbPage>{item.label}</BreadcrumbPage>
              )}
            </BreadcrumbItem>
            {index < pathLinks.length - 1 && (
              <BreadcrumbSeparator
                className={index === 0 ? "hidden md:block" : ""}
              />
            )}
          </Fragment>
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
