CREATE TABLE daily_website_traffic (
    utc_day TEXT NOT NULL,
    page TEXT NOT NULL CHECK (page IN ('home', 'guide')),
    source TEXT NOT NULL CHECK (source IN ('direct', 'internal', 'github', 'google', 'bing', 'duckduckgo', 'baidu', 'reddit', 'hacker-news', 'x', 'linkedin', 'other')),
    country TEXT NOT NULL CHECK (length(country) = 2 OR country = 'unknown'),
    device TEXT NOT NULL CHECK (device IN ('desktop', 'mobile', 'tablet')),
    page_views INTEGER NOT NULL DEFAULT 0 CHECK (page_views >= 0),
    PRIMARY KEY (utc_day, page, source, country, device)
) WITHOUT ROWID;
