import { useEffect, useState } from "react";
import Pizza from "./Pizza";

const intl = new Intl.NumberFormat("ar-EG", {
  style: "currency",
  currency: "EUR",
});

export default function Order() {
  const [pizzaType, setPizzaType] = useState("pepperoni"); // state hook

  return (
    <div className="order">
      <h2>Create Order</h2>
      <form action="">
        <div>
          <div>
            <label htmlFor="pizza-type">Pizza Type</label>
            <select
              name="pizza-type"
              value={pizzaType}
              onChange={(e) => setPizzaType(e.target.value)}
            >
              <option value="pepperoni">pizza pepperoni</option>
              <option value="hawaiian">pizaa hawaiian</option>
              <option value="big_meat"></option>
            </select>
          </div>
          <button></button>
        </div>
      </form>
    </div>
  );
}
