export const fetchSample = () => {
  return fetch(`/haskell-cafe/2018-October.txt`).then((response) =>
    response.text()
  );
};
