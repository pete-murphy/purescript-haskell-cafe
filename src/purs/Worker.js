export const sendMessage = (message) => () => {
  self.postMessage(message);
};
