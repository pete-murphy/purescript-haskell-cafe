export default {
  async fetch(request, env, ctx): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/haskell-cafe")) {
      return fetch(`https://mail.haskell.org/pipermail${url.pathname}`, {
        method: request.method,
        headers: request.headers,
      });
    }

    console.log(request, env, ctx);
    // @ts-ignore
    return env.ASSETS.fetch(request);
  },
} satisfies ExportedHandler<Cloudflare.Env>;
