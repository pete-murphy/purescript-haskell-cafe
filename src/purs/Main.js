export function onMessages(worker) {
  return (callback) => {
    return () =>
      (worker.onmessage = (event) => {
        callback(event.data)();
      });
  };
}

export function addToDOM(message) {
  return () => {
    document.body.appendChild(document.createElement("pre")).textContent =
      message;
  };
}
