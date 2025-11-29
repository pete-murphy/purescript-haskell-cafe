import fs from "node:fs/promises";

export function _fetch(filename) {
  const url = `https://mail.haskell.org/pipermail/haskell-cafe/${filename}`;
  return async () => {
    const response = await fetch(url);
    const buffer = Buffer.from(await response.arrayBuffer());
    return fs.writeFile(`./file-server/haskell-cafe/${filename}`, buffer);
  };
}
