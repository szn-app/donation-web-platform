import { createLazyFileRoute } from "@tanstack/react-router";
import { NavProjects } from "@/components/nav-projects";
import { NavMain } from "@/components/nav-main";
import { navMainData, projects } from "@/data/retailer-navigation";

export const Route = createLazyFileRoute("/_app/retailer")({
  component,
});

const collections = [
  {
    name: "City Style",
    href: "#",
    imageSrc: "/image-7.png",
    imageAlt: "Mall. Cloths. Brands.",
  },
  {
    name: "Tech Treats",
    href: "#",
    imageSrc: "image-12.png",
    imageAlt: "Computers. Electronics. Devices.",
  },
  {
    name: "Cabin Comforts",
    href: "#",
    imageSrc: "image-13.png",
    imageAlt: "Furniture. House. Items.",
  },
];

export default function component() {
  return (
    <div className="relative bg-white">
      {/* Background image and overlap */}
      <div
        aria-hidden="true"
        className="absolute inset-0 hidden sm:flex sm:flex-col"
      >
        <div className="relative w-full flex-1 bg-gray-800">
          <div className="absolute inset-0 overflow-hidden">
            <img
              alt=""
              src="/image-8.png"
              className="h-full w-full object-cover object-center"
            />
          </div>
          <div className="absolute inset-0 bg-gray-900 opacity-50" />
        </div>
        <div className="h-32 w-full bg-white md:h-40 lg:h-48" />
      </div>

      <div className="relative mx-auto max-w-3xl px-4 pb-96 text-center sm:px-6 sm:pb-0 lg:px-8">
        {/* Background image and overlap */}
        <div
          aria-hidden="true"
          className="absolute inset-0 flex flex-col sm:hidden"
        >
          <div className="relative w-full flex-1 bg-gray-800">
            <div className="absolute inset-0 overflow-hidden">
              <img
                alt=""
                src="/image-8.png"
                className="h-full w-full object-cover object-center"
              />
            </div>
            <div className="absolute inset-0 bg-gray-900 opacity-50" />
          </div>
          <div className="h-48 w-full bg-white" />
        </div>
        <div className="relative py-32">
          <h1 className="text-4xl font-bold tracking-tight text-white sm:text-5xl md:text-6xl">
            Buy & Sell Market
          </h1>
          <button className="mt-4 sm:mt-6">
            <a
              href="#"
              className="inline-block rounded-md border border-transparent px-8 py-3 font-medium text-white hover:bg-indigo-700 active:bg-indigo-600"
            >
              Coming Soon
            </a>
          </button>
        </div>
      </div>

      <section
        aria-labelledby="collection-heading"
        className="relative -mt-96 animate-in slide-in-from-bottom-1/3 sm:mt-0"
      >
        <h2 id="collection-heading" className="sr-only">
          Collections
        </h2>
        <div className="mx-auto grid max-w-md grid-cols-1 gap-y-6 px-4 sm:max-w-7xl sm:grid-cols-3 sm:gap-x-6 sm:gap-y-0 sm:px-6 lg:gap-x-8 lg:px-8">
          {collections.map((collection, index) => (
            <div
              key={collection.name}
              className={`group relative h-96 rounded-lg bg-white shadow-xl sm:aspect-h-5 sm:aspect-w-4 sm:h-auto ${
                index === 1 ? "animate-in slide-in-from-bottom-1/3" : ""
              }`}
            >
              <div>
                <div
                  aria-hidden="true"
                  className="absolute inset-0 overflow-hidden rounded-lg"
                >
                  <div className="absolute inset-0 overflow-hidden group-hover:opacity-75">
                    <img
                      alt={collection.imageAlt}
                      src={collection.imageSrc}
                      className="h-full w-full object-cover object-center"
                    />
                  </div>
                  <div className="absolute inset-0 bg-gradient-to-b from-transparent to-black opacity-50" />
                </div>
                <div className="absolute inset-0 flex items-end rounded-lg p-6">
                  <div>
                    <p aria-hidden="true" className="text-sm text-white">
                      Shop the collection
                    </p>
                    <h3 className="mt-1 font-semibold text-white drop-shadow-[0_1px_1px_rgba(0,0,0,1)]">
                      <a href={collection.href}>
                        <span className="absolute inset-0" />
                        {collection.name}
                      </a>
                    </h3>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>
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
