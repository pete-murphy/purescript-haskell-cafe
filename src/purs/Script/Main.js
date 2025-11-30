import fs from "node:fs/promises";

export function fetchFileImpl(filename) {
  const url = `https://mail.haskell.org/pipermail/haskell-cafe/${filename}`;
  return async () => {
    const start = Date.now();
    const response = await fetch(url);
    const buffer = Buffer.from(await response.arrayBuffer());
    await fs.writeFile(`./file-server/haskell-cafe/${filename}`, buffer);
    const end = Date.now();
    console.log(
      `${(filename + " ").padEnd(30, ".")} ${(end - start + "ms ").padEnd(10, ".")} ${performance.now()}`
    );
    return;
  };
}
