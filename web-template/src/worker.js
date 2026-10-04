const SESSION_COOKIE = "p008_session";
const STATE_COOKIE = "p008_oauth_state";
const SESSION_TTL_SECONDS = 60 * 60;
const STATE_TTL_SECONDS = 10 * 60;

function json(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "x-robots-tag": "noindex, nofollow",
      ...extraHeaders,
    },
  });
}

function securityHeaders(contentType = "text/html; charset=utf-8") {
  return {
    "content-type": contentType,
    "cache-control": "no-store",
    "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
    "referrer-policy": "no-referrer",
    "x-content-type-options": "nosniff",
    "x-frame-options": "DENY",
    "x-robots-tag": "noindex, nofollow",
  };
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function parseCookies(request) {
  const result = {};
  const raw = request.headers.get("cookie") || "";
  for (const part of raw.split(";")) {
    const index = part.indexOf("=");
    if (index <= 0) continue;
    const name = part.slice(0, index).trim();
    const value = part.slice(index + 1).trim();
    if (name) result[name] = value;
  }
  return result;
}

function base64url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/u, "");
}

function base64urlText(text) {
  return base64url(new TextEncoder().encode(text));
}

function decodeBase64url(value) {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function randomToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64url(bytes);
}

function isAuthConfigured(env) {
  return Boolean(
    typeof env.GITHUB_OAUTH_CLIENT_ID === "string" &&
    env.GITHUB_OAUTH_CLIENT_ID.trim() &&
    typeof env.GITHUB_OAUTH_CLIENT_SECRET === "string" &&
    env.GITHUB_OAUTH_CLIENT_SECRET.trim(),
  );
}

async function sessionKey(secret) {
  const material = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`p008-session-v1:${secret}`),
  );
  return crypto.subtle.importKey(
    "raw",
    material,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

async function createSession(user, env, nowSeconds = Math.floor(Date.now() / 1000)) {
  const payload = {
    sub: `github:${user.id}`,
    provider: "github",
    id: user.id,
    login: user.login,
    iat: nowSeconds,
    exp: nowSeconds + SESSION_TTL_SECONDS,
  };
  const encoded = base64urlText(JSON.stringify(payload));
  const key = await sessionKey(env.GITHUB_OAUTH_CLIENT_SECRET);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(encoded));
  return `${encoded}.${base64url(new Uint8Array(signature))}`;
}

async function readSession(request, env, nowSeconds = Math.floor(Date.now() / 1000)) {
  if (!isAuthConfigured(env)) return null;
  const token = parseCookies(request)[SESSION_COOKIE];
  if (!token) return null;
  const parts = token.split(".");
  if (parts.length !== 2) return null;

  try {
    const [encoded, signature] = parts;
    const key = await sessionKey(env.GITHUB_OAUTH_CLIENT_SECRET);
    const valid = await crypto.subtle.verify(
      "HMAC",
      key,
      decodeBase64url(signature),
      new TextEncoder().encode(encoded),
    );
    if (!valid) return null;

    const payload = JSON.parse(new TextDecoder().decode(decodeBase64url(encoded)));
    if (
      payload?.provider !== "github" ||
      !Number.isSafeInteger(payload?.id) ||
      typeof payload?.login !== "string" ||
      !Number.isFinite(payload?.exp) ||
      payload.exp <= nowSeconds
    ) {
      return null;
    }
    return payload;
  } catch {
    return null;
  }
}

function stateCookie(value) {
  return `${STATE_COOKIE}=${value}; Max-Age=${STATE_TTL_SECONDS}; Path=/auth; HttpOnly; Secure; SameSite=Lax`;
}

function clearStateCookie() {
  return `${STATE_COOKIE}=; Max-Age=0; Path=/auth; HttpOnly; Secure; SameSite=Lax`;
}

function sessionCookie(value) {
  return `${SESSION_COOKIE}=${value}; Max-Age=${SESSION_TTL_SECONDS}; Path=/; HttpOnly; Secure; SameSite=Lax`;
}

function clearSessionCookie() {
  return `${SESSION_COOKIE}=; Max-Age=0; Path=/; HttpOnly; Secure; SameSite=Lax`;
}

function redirect(location, status = 302, cookies = []) {
  const headers = new Headers({
    location,
    "cache-control": "no-store",
    "referrer-policy": "no-referrer",
    "x-content-type-options": "nosniff",
  });
  for (const cookie of cookies) headers.append("set-cookie", cookie);
  return new Response(null, { status, headers });
}

function renderHtml(user, authConfigured) {
  const authPanel = !authConfigured
    ? `<section class="card warn"><h2>OAuth設定待ち</h2><p>GitHub OAuth App のClient ID / Client Secretを安全な実行環境へ設定するとログイン確認を開始できます。</p></section>`
    : user
      ? `<section class="card"><h2>ログイン済み</h2><p>GitHub: <strong>@${escapeHtml(user.login)}</strong></p><p class="muted">識別子: github:${escapeHtml(user.id)}</p><form method="post" action="/auth/logout"><button type="submit">ログアウト</button></form></section>`
      : `<section class="card"><h2>ソーシャルログイン</h2><p>GitHubアカウントでログインできます。このPoCはメールアドレスを要求・保存しません。</p><a class="button" href="/auth/login">GitHubでログイン</a></section>`;

  return `<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="robots" content="noindex,nofollow">
  <title>P008 Social Login Preview</title>
  <style>
    body{font-family:system-ui,sans-serif;margin:0;background:#f6f7f9;color:#1f2937}
    main{max-width:760px;margin:48px auto;padding:28px;background:#fff;border:1px solid #e5e7eb;border-radius:16px}
    .card{margin-top:22px;padding:20px;border:1px solid #e5e7eb;border-radius:12px}
    .warn{background:#fffbeb}
    .muted{color:#6b7280}
    .button,button{display:inline-block;border:0;border-radius:8px;padding:10px 16px;background:#111827;color:#fff;text-decoration:none;font:inherit;cursor:pointer}
    code{background:#f3f4f6;padding:.15em .35em;border-radius:4px}
  </style>
</head>
<body>
  <main>
    <h1>P008 Free Preview</h1>
    <p>Cloudflare Workers Preview + D1 の完全無料PoCです。R2は使用しません。</p>
    ${authPanel}
    <p class="muted">認証状態は署名付きHttpOnly Cookieで保持し、ユーザー情報をD1へ保存しません。</p>
  </main>
</body>
</html>`;
}

async function startGithubLogin(request, env) {
  if (request.method !== "GET") return json({ ok: false, error: "method_not_allowed" }, 405);
  if (!isAuthConfigured(env)) {
    return json({
      ok: false,
      error: "auth_not_configured",
      required: ["GITHUB_OAUTH_CLIENT_ID", "GITHUB_OAUTH_CLIENT_SECRET"],
    }, 503);
  }

  const url = new URL(request.url);
  const state = randomToken();
  const callback = `${url.origin}/auth/callback`;
  const authorize = new URL("https://github.com/login/oauth/authorize");
  authorize.searchParams.set("client_id", env.GITHUB_OAUTH_CLIENT_ID);
  authorize.searchParams.set("redirect_uri", callback);
  authorize.searchParams.set("state", state);
  authorize.searchParams.set("allow_signup", "false");

  return redirect(authorize.toString(), 302, [stateCookie(state)]);
}

async function githubCallback(request, env) {
  if (request.method !== "GET") return json({ ok: false, error: "method_not_allowed" }, 405);
  if (!isAuthConfigured(env)) return json({ ok: false, error: "auth_not_configured" }, 503);

  const url = new URL(request.url);
  const expectedState = parseCookies(request)[STATE_COOKIE];
  const receivedState = url.searchParams.get("state");
  const code = url.searchParams.get("code");

  if (!expectedState || !receivedState || expectedState !== receivedState || !code) {
    const response = json({ ok: false, error: "invalid_oauth_callback" }, 400);
    response.headers.append("set-cookie", clearStateCookie());
    return response;
  }

  const tokenResponse = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: {
      accept: "application/json",
      "content-type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      client_id: env.GITHUB_OAUTH_CLIENT_ID,
      client_secret: env.GITHUB_OAUTH_CLIENT_SECRET,
      code,
      redirect_uri: `${url.origin}/auth/callback`,
    }),
  });
  if (!tokenResponse.ok) {
    const response = json({ ok: false, error: "oauth_token_exchange_failed" }, 502);
    response.headers.append("set-cookie", clearStateCookie());
    return response;
  }

  const tokenBody = await tokenResponse.json();
  if (typeof tokenBody?.access_token !== "string" || !tokenBody.access_token) {
    const response = json({ ok: false, error: "oauth_token_missing" }, 502);
    response.headers.append("set-cookie", clearStateCookie());
    return response;
  }

  const userResponse = await fetch("https://api.github.com/user", {
    headers: {
      accept: "application/vnd.github+json",
      authorization: `Bearer ${tokenBody.access_token}`,
      "user-agent": "P008-Web-PoC",
      "x-github-api-version": "2022-11-28",
    },
  });
  if (!userResponse.ok) {
    const response = json({ ok: false, error: "oauth_user_fetch_failed" }, 502);
    response.headers.append("set-cookie", clearStateCookie());
    return response;
  }

  const githubUser = await userResponse.json();
  if (!Number.isSafeInteger(githubUser?.id) || typeof githubUser?.login !== "string") {
    const response = json({ ok: false, error: "oauth_user_invalid" }, 502);
    response.headers.append("set-cookie", clearStateCookie());
    return response;
  }

  const session = await createSession({ id: githubUser.id, login: githubUser.login }, env);
  return redirect("/", 302, [clearStateCookie(), sessionCookie(session)]);
}

async function logout(request) {
  if (request.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);
  return redirect("/", 303, [clearSessionCookie()]);
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
          auth_provider: "github",
          auth_configured: isAuthConfigured(env),
        });
      } catch (error) {
        return json({
          ok: false,
          environment: env.ENVIRONMENT || "unknown",
          r2_enabled: false,
          auth_provider: "github",
          auth_configured: isAuthConfigured(env),
          error: error instanceof Error ? error.message : "unknown error",
        }, 500);
      }
    }

    if (url.pathname === "/auth/login") return startGithubLogin(request, env);
    if (url.pathname === "/auth/callback") return githubCallback(request, env);
    if (url.pathname === "/auth/logout") return logout(request);

    if (url.pathname === "/api/me") {
      if (request.method !== "GET") return json({ ok: false, error: "method_not_allowed" }, 405);
      const user = await readSession(request, env);
      if (!user) return json({ authenticated: false }, 401);
      return json({
        authenticated: true,
        provider: "github",
        id: user.id,
        login: user.login,
      });
    }

    if (url.pathname !== "/" || (request.method !== "GET" && request.method !== "HEAD")) {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return json({ ok: false, error: "method_not_allowed" }, 405);
      }
      return json({ ok: false, error: "not_found" }, 404);
    }

    const user = await readSession(request, env);
    const html = renderHtml(user, isAuthConfigured(env));
    return new Response(request.method === "HEAD" ? null : html, {
      headers: securityHeaders(),
    });
  },
};
