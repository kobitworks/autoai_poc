const HTML = `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <title>P008 Free Preview</title>
  <style>
    body{font-family:system-ui,sans-serif;margin:0;background:#f6f7f9;color:#1f2937}
    main{max-width:760px;margin:48px auto;padding:28px;background:#fff;border:1px solid #e5e7eb;border-radius:16px}
    code{background:#f3f4f6;padding:.15em .35em;border-radius:4px}
  </style>
</head>
<body>
  <main>
    <h1>P008 Free Preview</h1>
    <p>Cloudflare Workers Preview + D1 の完全無料PoC疎通確認用です。</p>
    <p>R2は使用しません。ファイル保存が必要なPoCは静的ファイル、モック、LocalStorage / IndexedDB等で代替します。</p>
    <p>このPreviewではD1への書込みを行いません。<code>/health</code> でD1 binding状態を確認できます。</p>
  </main>
</body>
</html>`;

function json(data, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-robots-tag": "noindex, nofollow",
    },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/health") {
      try {
        const d1 = await env.DB.prepare("SELECT 1 AS ok").first();
        return json({
          ok: d1?.ok === 1,
          environment: env.ENVIRONMENT || "unknown",
          db_write_enabled: env.DB_WRITE_ENABLED === "true",
          d1_read: d1?.ok === 1,
          file_storage_mode: env.FILE_STORAGE_MODE || "none",
          r2_enabled: false,
          zero_cost_guard: true,
        });
      } catch (error) {
        return json({
          ok: false,
          environment: env.ENVIRONMENT || "unknown",
          r2_enabled: false,
          error: error instanceof Error ? error.message : "unknown error",
        }, 500);
      }
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      return json({ ok: false, error: "method_not_allowed" }, 405);
    }

    return new Response(request.method === "HEAD" ? null : HTML, {
      headers: {
        "content-type": "text/html; charset=utf-8",
        "cache-control": "no-store",
        "x-robots-tag": "noindex, nofollow",
      },
    });
  },
};
