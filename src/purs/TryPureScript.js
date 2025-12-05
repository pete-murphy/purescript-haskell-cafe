export function setInnerHTML(html) {
  return () => {
    document.getElementById("app").innerHTML += html;
  };
}
