import { useEffect, useState } from "react";
import { createLazyFileRoute } from "@tanstack/react-router";
import { NavProjects } from "@/components/nav-projects";
import { NavMain } from "@/components/nav-main";
import { navMainData, projects } from "@/data/donation-navigation";

export const Route = createLazyFileRoute("/_app/donation")({
  component,
  notFoundComponent: () => {
    return <h1>Not Found! from _app/page-1</h1>;
  },
});

type Product = {
  id: number;
  name: string;
  href: string;
  price: string;
  description: string;
  options: string;
  imageSrc: string;
  imageAlt: string;
};

const products: Product[] = [
  {
    id: 1,
    name: "Apple iPhone 13",
    href: "https://www.apple.com/iphone-13/",
    price: "",
    description:
      "The latest iPhone with A15 Bionic chip and advanced dual-camera system.",
    options: "128GB, 256GB, 512GB",
    imageSrc:
      "https://www.spex.co.il/wp-content/uploads/apple-iphone-13-01.jpg",
    imageAlt: "Apple iPhone 13 in various colors.",
  },
  {
    id: 2,
    name: "Samsung Galaxy S21",
    href: "https://www.samsung.com/global/galaxy/galaxy-s21-5g/",
    price: "",
    description:
      "Experience the new Samsung Galaxy S21 with 8K video recording and 64MP camera.",
    options: "128GB, 256GB",
    imageSrc:
      "https://the-lab.co.il/wp-content/uploads/2021/01/samsung-galaxy-s21-5g-0.jpg",
    imageAlt: "Samsung Galaxy S21 in various colors.",
  },
  {
    id: 3,
    name: "Sony WH-1000XM4",
    href: "https://www.sony.com/electronics/headband-headphones/wh-1000xm4",
    price: "",
    description:
      "Industry-leading noise canceling with Dual Noise Sensor technology.",
    options: "Black, Silver",
    imageSrc: "https://m.media-amazon.com/images/I/6162Umyop-L.jpg",
    imageAlt: "Sony WH-1000XM4 headphones in black.",
  },
  {
    id: 4,
    name: "Dell XPS 13",
    href: "https://www.dell.com/en-us/shop/dell-laptops/xps-13-laptop/spd/xps-13-9310-laptop",
    price: "",
    description:
      "Compact 13-inch laptop with a stunning 4-sided InfinityEdge display.",
    options: "8GB, 16GB RAM",
    imageSrc:
      "https://m.media-amazon.com/images/I/710EGJBdIML._AC_UF894,1000_QL80_.jpg",
    imageAlt: "Dell XPS 13 laptop.",
  },
  {
    id: 5,
    name: "Apple Watch Series 7",
    href: "https://www.apple.com/apple-watch-series-7/",
    price: "",
    description: "The largest, most advanced Always-On Retina display.",
    options: "41mm, 45mm",
    imageSrc: "https://img.zap.co.il/pics/4/1/1/8/66218114c.gif",
    imageAlt: "Apple Watch Series 7 in blue.",
  },
  {
    id: 6,
    name: "Nintendo Switch",
    href: "https://www.nintendo.com/switch/",
    price: "",
    description:
      "Versatile gaming console that can be used at home or on the go.",
    options: "Neon Blue/Red, Gray",
    imageSrc:
      "https://static.independent.co.uk/2023/03/07/11/Nintendo%20Switch%20Indybest%20copy.jpg",
    imageAlt: "Nintendo Switch console.",
  },
  {
    id: 7,
    name: "Bose QuietComfort 35 II",
    href: "https://www.bose.com/en_us/products/headphones/over_ear_headphones/quietcomfort-35-ii.html",
    price: "",
    description:
      "Wireless Bluetooth headphones with world-class noise cancellation.",
    options: "Black, Silver",
    imageSrc:
      "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRa7n5oCFBqrl56cVHMZa_7nni2n2ER-3Fw0g&s",
    imageAlt: "Bose QuietComfort 35 II headphones in black.",
  },
  {
    id: 8,
    name: "Fitbit Charge 5",
    href: "https://www.fitbit.com/global/us/products/trackers/charge5",
    price: "",
    description:
      "Advanced fitness and health tracker with built-in GPS and stress management tools.",
    options: "Black, Lunar White, Steel Blue",
    imageSrc:
      "https://www.avitela.lt/UserFiles/Products/Images/296849-448310-medium.png",
    imageAlt: "Fitbit Charge 5 in black.",
  },
];

export default function component() {
  return (
    <div className="mx-auto max-w-2xl px-4 py-5 sm:px-6 sm:py-10 lg:max-w-7xl lg:px-8">
      <h2 className="sr-only">Products</h2>

      <div className="grid grid-cols-1 gap-y-4 sm:grid-cols-2 sm:gap-x-6 sm:gap-y-10 lg:grid-cols-3 lg:gap-x-8">
        {products.map((product) => (
          <div
            key={product.id}
            className="group relative flex flex-col overflow-hidden rounded-lg border border-gray-200 bg-white"
          >
            <div className="aspect-h-4 aspect-w-3 bg-gray-200 sm:aspect-none group-hover:opacity-75 sm:h-96">
              <img
                alt={product.imageAlt}
                src={product.imageSrc}
                className="h-full w-full object-cover object-center sm:h-full sm:w-full"
              />
            </div>
            <div className="flex flex-1 flex-col space-y-2 p-4">
              <h3 className="text-sm font-medium text-gray-900">
                <a href={product.href}>
                  <span aria-hidden="true" className="absolute inset-0" />
                  {product.name}
                </a>
              </h3>
              <p className="text-sm text-gray-500">{product.description}</p>
              <div className="flex flex-1 flex-col justify-end">
                <p className="text-sm italic text-gray-500">
                  {product.options}
                </p>
                <p className="text-base font-medium text-gray-900">
                  {product.price}
                </p>
              </div>
            </div>
          </div>
        ))}
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
