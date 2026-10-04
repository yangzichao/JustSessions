-- One row per UTC day and app version. No IP address, user agent, or other identifier is stored.
CREATE TABLE daily_update_checks (
    utc_day TEXT NOT NULL,
    app_version TEXT NOT NULL,
    check_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (utc_day, app_version)
) WITHOUT ROWID;
