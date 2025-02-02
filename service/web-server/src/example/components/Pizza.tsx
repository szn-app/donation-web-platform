let counter = 0; // keep track of state outside of react

function Pizza(props: any) {
  counter = Date.now();

  return (
    <div
      className="pizza"
      onClick={() => {
        console.log("hi");
      }}
    >
      <h1>
        {props.type} {counter}
      </h1>
      <img
        src="https://letsenhance.io/static/a31ab775f44858f1d1b80ee51738f4f3/11499/EnhanceAfter.jpg"
        alt="some-icon"
      />
    </div>
  );
}

export default Pizza;
