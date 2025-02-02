export default async function getPastOrders(page: Number) {
  const response = await fetch(`/api/past-orders?page=${page}`);
  const data = await response.json();

  return data;
}

// usage: https://github.com/btholt/citr-v9-project/blob/main/10-query/src/routes/past.lazy.jsx#L12
