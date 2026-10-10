CREATE TABLE feedback (
    id INTEGER PRIMARY KEY,
    received_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    source TEXT NOT NULL CHECK (source IN ('website', 'app')),
    message TEXT NOT NULL CHECK (length(message) BETWEEN 1 AND 5000),
    contact TEXT CHECK (contact IS NULL OR length(contact) <= 200),
    app_version TEXT CHECK (app_version IS NULL OR length(app_version) <= 40),
    macos_version TEXT CHECK (macos_version IS NULL OR length(macos_version) <= 40)
);

CREATE INDEX feedback_by_received_at ON feedback (received_at);
