import { createLazyFileRoute } from "@tanstack/react-router";
import { NavProjects } from "@/components/nav-projects";
import { NavMain } from "@/components/nav-main";

export const Route = createLazyFileRoute("/_app/market")({
  component,
});

import { navMainData, projects } from "@/data/market-navigation";

export default function component() {
  const imageColumns = [
    ["/image-14.png", "/image-18.png"],
    ["/image-16.png", "/image-13.png"],
    ["/image-15.png", "/image-16.jpeg"],
  ];

  return (
    <div className="bg-white">
      <div className="overflow-hidden pt-32 sm:pt-14">
        <div className="bg-gray-800">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
            <div className="relative animate-appearance-in pb-16 pt-48 sm:pb-24">
              <div>
                <h2
                  id="sale-heading"
                  className="text-4xl font-bold tracking-tight text-white md:text-5xl"
                >
                  Coming
                  <br />
                  &nbsp;&nbsp;&nbsp;&nbsp;Soon.
                </h2>
                <div className="mt-6 hidden text-base">
                  <a href="#" className="font-semibold text-white">
                    Shop the sale
                    <span aria-hidden="true"> &rarr;</span>
                  </a>
                </div>
              </div>

              <div className="absolute -top-32 left-1/3 min-w-max -translate-x-1/2 transform sm:top-6 sm:translate-x-0">
                <div className="ml-24 flex space-x-6 sm:ml-3 lg:space-x-8">
                  {imageColumns.map((column, columnIndex) => (
                    <div
                      key={columnIndex}
                      className={`flex space-x-6 ${
                        columnIndex === 1 ? "sm:-mt-20" : ""
                      } sm:flex-col sm:space-x-0 sm:space-y-6 lg:space-y-8`}
                    >
                      {column.map((src, index) => (
                        <div
                          key={index}
                          className={`flex-shrink-0 ${
                            index === 1 ? "mt-6 sm:mt-0" : ""
                          }`}
                        >
                          <img
                            alt=""
                            src={src}
                            className="h-64 w-64 rounded-lg object-cover md:h-72 md:w-72"
                          />
                        </div>
                      ))}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export function SidebarContent() {
  return (
    <>
      <NavMain items={navMainData} />
      <NavProjects projects={projects} />
    </>
  );
}
