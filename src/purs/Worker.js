export const sendMessage = (message) => () => {
  self.postMessage(message);
};

export const debugMessage = (message) => () => {
  self.postMessage(message);
};

export const fetchSample = () => {
  return fetch(`/haskell-cafe/2018-August.txt`).then((response) =>
    response.text()
  );
  // let sample = "";
  // return fetch(`/haskell-cafe/2005-August.txt.gz`)
  //   .then((response) =>
  //     response.body
  //       .pipeThrough(new DecompressionStream("gzip"))
  //       .pipeThrough(new TextDecoderStream())
  //       .pipeTo(
  //         new WritableStream({
  //           write(chunk) {
  //             sample += chunk;
  //           },
  //         })
  //       )
  //   )
  //   .then(() => sample);
};
