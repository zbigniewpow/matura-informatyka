// Bramka: aplikację dostaje tylko zalogowany uczeń z listy (albo aktywny nauczyciel).
// Działa na brzegu sieci Netlify, zanim plik index.html zostanie wysłany do przeglądarki.
const SUPABASE_URL = "https://dmxelijuwivtgrzklrfi.supabase.co";
const SUPABASE_KEY = "sb_publishable_z_v-sxh99aeZje3_iT-gTg_944t022v";

function readCookie(header, name) {
  const m = (header || "").match(new RegExp("(?:^|;\\s*)" + name + "=([^;]+)"));
  return m ? decodeURIComponent(m[1]) : null;
}

export async function hasAccess(token, fetchImpl = fetch) {
  if (!token || token.length > 4096) return false;
  try {
    const r = await fetchImpl(`${SUPABASE_URL}/rest/v1/rpc/has_access`, {
      method: "POST",
      headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: "{}",
    });
    if (!r.ok) return false;
    return (await r.json()) === true;
  } catch {
    return false;
  }
}

export default async (request, context) => {
  const url = new URL(request.url);
  const token = readCookie(request.headers.get("cookie"), "mi_at");
  if (!(await hasAccess(token))) {
    const login = new URL("/login.html", url);
    const next = url.pathname + url.search;
    if (next !== "/") login.searchParams.set("next", next);
    return new Response(null, {
      status: 302,
      headers: { Location: login.pathname + login.search, "Cache-Control": "no-store" },
    });
  }
  const res = await context.next();
  const headers = new Headers(res.headers);
  headers.set("Cache-Control", "private, no-store");
  headers.set("X-Robots-Tag", "noindex");
  return new Response(res.body, { status: res.status, headers });
};

export const config = {
  path: "/*",
  excludedPath: ["/login.html", "/prywatnosc.html", "/favicon.ico", "/robots.txt", "/manifest.webmanifest", "/icon-192.png", "/icon-512.png"],
};
