// Lead buffer for flows.techxeon.cloud — protects client form submissions during
// maintenance. Runs as a Worker on route flows.techxeon.cloud/*.
//
// KV key "mode":
//   "pass"   (default) every request goes straight to n8n; buffered items are replayed by the cron
//   "buffer" webhook POSTs are stored in KV and answered 200, nothing reaches the origin
//
// Cron (every minute): in "pass" mode, replays stored submissions to the origin,
// oldest first, deleting each one only after the origin answers 2xx.

const BUFFERED = /^\/(webhook|form)\//;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const mode = (await env.BUF.get("mode")) || "pass";

    if (mode === "buffer" && request.method === "POST" && BUFFERED.test(url.pathname)) {
      const item = {
        at: new Date().toISOString(),
        method: request.method,
        path: url.pathname + url.search,
        contentType: request.headers.get("content-type") || "",
        body: await request.text(),
      };
      const key = `q:${Date.now()}:${crypto.randomUUID()}`;
      await env.BUF.put(key, JSON.stringify(item));
      return Response.json({ message: "Workflow was started" });
    }
    return fetch(request);
  },

  async scheduled(_event, env) {
    const mode = (await env.BUF.get("mode")) || "pass";
    if (mode !== "pass") return;
    const list = await env.BUF.list({ prefix: "q:", limit: 50 });
    for (const k of list.keys) {
      const raw = await env.BUF.get(k.name);
      if (!raw) continue;
      const item = JSON.parse(raw);
      const res = await fetch(`https://${env.ORIGIN_HOST}${item.path}`, {
        method: item.method,
        headers: { "content-type": item.contentType, "x-replayed-from-buffer": item.at },
        body: item.body,
      });
      if (res.ok) await env.BUF.delete(k.name);
      else { await env.BUF.put("last_replay_error", `${res.status} ${item.path} ${new Date().toISOString()}`); break; }
    }
  },
};
