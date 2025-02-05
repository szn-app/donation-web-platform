import { createLazyFileRoute, Link } from '@tanstack/react-router'

export const Route = createLazyFileRoute('/_app/p1')({
  component: RouteComponent,
  notFoundComponent: () => {
    return <h1>Not Found! from _app/p1</h1>
  },
})

const str: string = '/product'

function RouteComponent() {
  return (
    <div>
      <Link to={str}> Hello "/p1"! </Link>
    </div>
  )
}
