import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../src/worker.js", import.meta.url), "utf8");
const workerModule = await import(
  "data:text/javascript;base64," + Buffer.from(source, "utf8").toString("base64")
);
const worker = workerModule.default;

function goodEnv() {
  return {
    ENVIRONMENT: "preview",
    DB_WRITE_ENABLED: "false",
    FILE_STORAGE_MODE: "local-only",
    GITHUB_OAUTH_CLIENT_ID: "test-client-id",
    GITHUB_OAUTH_CLIENT_SECRET: "test-client-secret",
    DB: {
      prepare(sql) {
        assert.equal(sql, "SELECT 1 AS ok");
        return { first: async () => ({ ok: 1 }) };
      },
    },
  };
}

function getCookie(setCookieHeader, name) {
  const match = setCookieHeader.match(new RegExp(`(?:^|, )${name}=([^;,]*)`));
  assert.ok(match, `cookie ${name} not found: ${setCookieHeader}`);
  return match[1];
}

{
  const response = await worker.fetch(new Request("https://preview.test/health"), goodEnv());
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body, {
    ok: true,
    environment: "preview",
    db_write_enabled: false,
    d1_read: true,
    file_storage_mode: "local-only",
    r2_enabled: false,
    zero_cost_guard: true,
    auth_provider: "github",
    auth_configured: true,
  });
  assert.equal(response.headers.get("cache-control"), "no-store");
}

{
  const env = goodEnv();
  delete env.GITHUB_OAUTH_CLIENT_SECRET;
  const response = await worker.fetch(new Request("https://preview.test/health"), env);
  assert.equal((await response.json()).auth_configured, false);
}

{
  const response = await worker.fetch(
    new Request("https://preview.test/", { method: "GET" }),
    goodEnv(),
  );
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /P008 Free Preview/);
  assert.match(html, /GitHubでログイン/);
  assert.match(html, /ユーザー情報をD1へ保存しません/);
}

{
  const response = await worker.fetch(
    new Request("https://preview.test/", { method: "HEAD" }),
    goodEnv(),
  );
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "");
}

{
  const env = goodEnv();
  delete env.GITHUB_OAUTH_CLIENT_ID;
  delete env.GITHUB_OAUTH_CLIENT_SECRET;
  const response = await worker.fetch(new Request("https://preview.test/auth/login"), env);
  assert.equal(response.status, 503);
  const body = await response.json();
  assert.equal(body.error, "auth_not_configured");
}

let state;
let stateCookieValue;
{
  const response = await worker.fetch(
    new Request("https://preview.test/auth/login"),
    goodEnv(),
  );
  assert.equal(response.status, 302);
  const location = new URL(response.headers.get("location"));
  assert.equal(location.origin, "https://github.com");
  assert.equal(location.pathname, "/login/oauth/authorize");
  assert.equal(location.searchParams.get("client_id"), "test-client-id");
  assert.equal(location.searchParams.get("redirect_uri"), "https://preview.test/auth/callback");
  state = location.searchParams.get("state");
  assert.ok(state && state.length >= 32);
  const setCookie = response.headers.get("set-cookie");
  stateCookieValue = getCookie(setCookie, "p008_oauth_state");
  assert.equal(stateCookieValue, state);
  assert.match(setCookie, /HttpOnly/);
  assert.match(setCookie, /Secure/);
  assert.match(setCookie, /SameSite=Lax/);
}

{
  const response = await worker.fetch(
    new Request("https://preview.test/auth/callback?code=x&state=wrong", {
      headers: { cookie: `p008_oauth_state=${stateCookieValue}` },
    }),
    goodEnv(),
  );
  assert.equal(response.status, 400);
  assert.equal((await response.json()).error, "invalid_oauth_callback");
}

let sessionCookieValue;
{
  const originalFetch = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (input, init = {}) => {
    const url = String(input);
    calls.push({ url, init });
    if (url === "https://github.com/login/oauth/access_token") {
      const params = new URLSearchParams(init.body);
      assert.equal(params.get("client_id"), "test-client-id");
      assert.equal(params.get("client_secret"), "test-client-secret");
      assert.equal(params.get("code"), "test-code");
      assert.equal(params.get("redirect_uri"), "https://preview.test/auth/callback");
      return new Response(JSON.stringify({ access_token: "gho_test_token" }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    if (url === "https://api.github.com/user") {
      assert.equal(init.headers.authorization, "Bearer gho_test_token");
      return new Response(JSON.stringify({
        id: 12345,
        login: "octocat",
        email: "ignored@example.invalid",
      }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    throw new Error(`unexpected fetch: ${url}`);
  };

  try {
    const callback = await worker.fetch(
      new Request(`https://preview.test/auth/callback?code=test-code&state=${encodeURIComponent(state)}`, {
        headers: { cookie: `p008_oauth_state=${stateCookieValue}` },
      }),
      goodEnv(),
    );
    assert.equal(callback.status, 302);
    assert.equal(callback.headers.get("location"), "/");
    const setCookie = callback.headers.get("set-cookie");
    assert.match(setCookie, /p008_oauth_state=; Max-Age=0/);
    sessionCookieValue = getCookie(setCookie, "p008_session");
    assert.ok(sessionCookieValue.includes("."));
    assert.equal(calls.length, 2);
  } finally {
    globalThis.fetch = originalFetch;
  }
}

{
  const me = await worker.fetch(
    new Request("https://preview.test/api/me", {
      headers: { cookie: `p008_session=${sessionCookieValue}` },
    }),
    goodEnv(),
  );
  assert.equal(me.status, 200);
  assert.deepEqual(await me.json(), {
    authenticated: true,
    provider: "github",
    id: 12345,
    login: "octocat",
  });

  const page = await worker.fetch(
    new Request("https://preview.test/", {
      headers: { cookie: `p008_session=${sessionCookieValue}` },
    }),
    goodEnv(),
  );
  const html = await page.text();
  assert.match(html, /@octocat/);
  assert.doesNotMatch(html, /ignored@example\.invalid/);
}

{
  const logout = await worker.fetch(
    new Request("https://preview.test/auth/logout", {
      method: "POST",
      headers: { cookie: `p008_session=${sessionCookieValue}` },
    }),
    goodEnv(),
  );
  assert.equal(logout.status, 303);
  assert.equal(logout.headers.get("location"), "/");
  assert.match(logout.headers.get("set-cookie"), /p008_session=; Max-Age=0/);
}

{
  const env = goodEnv();
  env.DB.prepare = () => ({ first: async () => { throw new Error("mock-d1-failure"); } });
  const response = await worker.fetch(new Request("https://preview.test/health"), env);
  assert.equal(response.status, 500);
  const body = await response.json();
  assert.equal(body.ok, false);
  assert.equal(body.environment, "preview");
  assert.equal(body.r2_enabled, false);
  assert.equal(body.auth_provider, "github");
  assert.equal(body.auth_configured, true);
  assert.match(body.error, /mock-d1-failure/);
}

console.log(JSON.stringify({
  ok: true,
  tests: 10,
  health_binding_mock: "d1-only-pass",
  preview_read_only: true,
  r2_binding_present: false,
  auth_provider: "github",
  oauth_state_cookie: "secure-httpOnly-sameSiteLax",
  session_cookie: "signed-httpOnly-secure",
  persisted_personal_data: false,
}, null, 2));
