import { render, cleanup } from "@testing-library/react";
import { expect, test, afterEach } from "vitest";
import Pizza from "../example/components/Pizza";

afterEach(cleanup);

test("name of test", async () => {
  const screen = render(
    <Pizza>
      <img src="" alt="" />
    </Pizza>,
  );

  const img = screen.getByRole("img") as HTMLImageElement;
  expect(img.src).toBe(
    "https://letsenhance.io/static/a31ab775f44858f1d1b80ee51738f4f3/11499/EnhanceAfter.jpg",
  );
});
