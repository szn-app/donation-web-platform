import { expect, test } from "vitest";
import { render } from "@testing-library/react";
import Order from "../example/components/Order";

test("snapshot with nothing in order", () => {
  const { asFragment } = render(<Order />);
  expect(asFragment()).toMatchSnapshot();
});
