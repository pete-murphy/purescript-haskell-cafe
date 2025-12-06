// @ts-ignore
import * as Worker from "../output/Worker/index.js";

Worker.main();

self.onmessage = (ev) => {
  console.log("ev from worker.ts", ev);
  self.postMessage("pong");
};
