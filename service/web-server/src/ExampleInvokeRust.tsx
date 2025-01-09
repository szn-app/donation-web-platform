import { useState } from "react";
import { FiAlertCircle } from "react-icons/fi";
import { invoke } from "@tauri-apps/api/core";

export default function ExampleInvokeRust() {
  const [greetMsg, setGreetMsg] = useState("");
  const [name, setName] = useState("");

  async function greet() {
    // Learn more about Tauri commands at https://tauri.app/develop/calling-rust/
    setGreetMsg(await invoke("greet", { name }));
  }

  return (
    <div className="container flex w-full max-w-lg items-center justify-center rounded bg-white p-10">
      <FiAlertCircle className="mg-atuo text-pink-20 mr-3 inline size-5 animate-spin text-center" />

      <form
        onSubmit={(e) => {
          e.preventDefault();
          greet();
        }}
      >
        <input
          id="greet-input"
          onChange={(e) => setName(e.currentTarget.value)}
          placeholder="Enter a value..."
        />
        <button
          className="mx-2 rounded border-red-400 bg-blue-700/50 px-2 py-2 text-white hover:bg-blue-700 hover:bg-yellow-400"
          type="submit"
        >
          execute Rust
        </button>
      </form>
      <p>{greetMsg}</p>
    </div>
  );
}
