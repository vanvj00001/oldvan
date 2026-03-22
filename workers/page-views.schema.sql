CREATE TABLE IF NOT EXISTS page_views (
  namespace TEXT NOT NULL,
  page_key TEXT NOT NULL,
  views INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (namespace, page_key)
);
