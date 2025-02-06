import { render } from "@testing-library/react";
import { expect, test } from "vitest";
import {
  BreadcrumbListComponent,
  generateBreadcrumbs,
} from "@/components/breadcrumb-list";
import { BrowserRouter } from "react-router-dom";

test("renders breadcrumb list with links", () => {
  const items = [
    { label: "Home", link: "/" },
    { label: "Products", link: "/products" },
    { label: "Electronics", link: "/products/electronics" },
    { label: "Laptops" },
  ];

  const { asFragment } = render(
    <BrowserRouter>
      <BreadcrumbListComponent items={items} />
    </BrowserRouter>,
  );

  expect(asFragment()).toMatchSnapshot();
});

test("generates breadcrumbs from pathname", () => {
  const pathname = "/products/electronics/laptops";
  const expectedBreadcrumbs = [
    { label: "Products", link: "/products" },
    { label: "Electronics", link: "/products/electronics" },
    { label: "Laptops" },
  ];

  const breadcrumbs = generateBreadcrumbs(pathname);
  expect(breadcrumbs).toEqual(expectedBreadcrumbs);
});

test("generates breadcrumbs for root pathname", () => {
  const pathname = "/";
  const expectedBreadcrumbs = [];

  const breadcrumbs = generateBreadcrumbs(pathname);
  expect(breadcrumbs).toEqual(expectedBreadcrumbs);
});
