export function worker() {
  return new Worker(new URL("../../src/worker.ts", import.meta.url), {
    type: "module",
  });
}

export function onMessages(worker) {
  return (callback) => {
    return () =>
      (worker.onmessage = (event) => {
        if (event.data.type === "fetch") {
          document.body.appendChild(document.createElement("h1")).textContent =
            event.data.message;
        } else callback(event.data.message)();
      });
  };
}

export function addToDOM(message) {
  return () => {
    document.body.appendChild(document.createElement("pre")).textContent =
      message;
  };
}
