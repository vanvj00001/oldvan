function json(data, init) {
  const headers = new Headers(init?.headers || {});
  headers.set("content-type", "application/json; charset=utf-8");
  headers.set("cache-control", "no-store");
  headers.set("access-control-allow-origin", "https://oldvan.top");
  headers.set("access-control-allow-methods", "POST, OPTIONS");
  headers.set("access-control-allow-headers", "content-type");

  return new Response(JSON.stringify(data), {
    headers,
    ...init
  });
}

function normalizeKey(value) {
  return String(value || "")
    .trim()
    .replace(/[^a-zA-Z0-9:_-]/g, "");
}

async function getCount(db, namespace, key) {
  const result = await db
    .prepare("SELECT views FROM page_views WHERE namespace = ?1 AND page_key = ?2")
    .bind(namespace, key)
    .first();

  return Number(result?.views || 0);
}

async function hitCount(db, namespace, key) {
  await db
    .prepare(`
      INSERT INTO page_views (namespace, page_key, views, updated_at)
      VALUES (?1, ?2, 1, CURRENT_TIMESTAMP)
      ON CONFLICT(namespace, page_key)
      DO UPDATE SET views = views + 1, updated_at = CURRENT_TIMESTAMP
    `)
    .bind(namespace, key)
    .run();

  return getCount(db, namespace, key);
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "access-control-allow-origin": "https://oldvan.top",
          "access-control-allow-methods": "POST, OPTIONS",
          "access-control-allow-headers": "content-type"
        }
      });
    }

    if (request.method !== "POST") {
      return json({ error: "method_not_allowed" }, { status: 405 });
    }

    if (!env.PAGE_VIEWS_DB) {
      return json({ error: "missing_database_binding" }, { status: 500 });
    }

    let payload;
    try {
      payload = await request.json();
    } catch (error) {
      return json({ error: "invalid_json" }, { status: 400 });
    }

    const mode = payload?.mode === "hit" ? "hit" : "get";
    const namespace = normalizeKey(payload?.namespace || "oldvan-top");
    const key = normalizeKey(payload?.key);

    if (!namespace || !key) {
      return json({ error: "invalid_key" }, { status: 400 });
    }

    const value =
      mode === "hit"
        ? await hitCount(env.PAGE_VIEWS_DB, namespace, key)
        : await getCount(env.PAGE_VIEWS_DB, namespace, key);

    return json({
      mode,
      namespace,
      key,
      value
    });
  }
};
