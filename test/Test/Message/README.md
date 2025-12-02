Metadata is extracted by running the following in Chrome dev tools (at https://mail.haskell.org/pipermail/haskell-cafe/2018-August/date.html#start for example)

```js
$$("ul:nth-of-type(2) li").map((li) => {
  const title = li.querySelector("a").textContent.slice(15).trim();
  const author = li.querySelector("i").textContent.trim();
  return { title, author };
});
```
