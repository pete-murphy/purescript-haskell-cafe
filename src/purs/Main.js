export function onMessages(worker) {
  return (callback) => {
    return () =>
      (worker.onmessage = (event) => {
        callback(event.data)();
      });
  };
}

export function addToDOM(message) {
  console.log("Adding to DOM", message);
  return () => {
    document.body.appendChild(document.createElement("pre")).textContent =
      message;
  };
}
