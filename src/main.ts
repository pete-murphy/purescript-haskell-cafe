import "./style.css";

// @ts-ignore
// import * as Main from "../output/Main/index.js";

const worker = new Worker(new URL("./worker.ts", import.meta.url), {
  type: "module",
});
worker.onmessage = (event) => {
  console.log(event.data);
};
console.log("Here");

// Main.main();
