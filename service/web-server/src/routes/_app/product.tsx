import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/_app/product')({
  component: RouteComponent,
})

function RouteComponent() {
  return <div className="h-screen w-screen bg-lime-300">Hello "/product"!</div>
}
