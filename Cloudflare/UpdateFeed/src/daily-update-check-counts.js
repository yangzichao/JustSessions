const incrementDailyUpdateCheckCount = `
    INSERT INTO daily_update_checks (utc_day, app_version, check_count) VALUES (?1, ?2, 1)
    ON CONFLICT (utc_day, app_version) DO UPDATE SET check_count = check_count + 1`;

/**
 * Adds one update check to the count for its UTC day and app version. Nothing else about the request is stored.
 * @param {D1Database} database
 * @param {string} appVersion
 * @param {Date} checkedAt
 */
export async function recordDailyUpdateCheck(database, appVersion, checkedAt) {
    const utcDay = checkedAt.toISOString().slice(0, 10);
    await database.prepare(incrementDailyUpdateCheckCount).bind(utcDay, appVersion).run();
}
