import Foundation

/// The Pi extension that reports the session a Pi CLI is in; see `LiveSessionReporting`. Pi starts its extensions'
/// `session_start` handlers when it starts, reloads, and with `/new`, `/resume`, `/fork`, and `/clone`, each time with
/// the session it then shows. Pi 0.65 and later.
enum PiLiveSessionExtension {
    static let fileName = "justsessions-live-session.js"

    static let source = #"""
        // JustSessions starts Pi with this extension and rewrites this file when the app changes it. It tells the app
        // which session this Pi is in, so the app's tab follows /new, /resume, /fork, and /clone.
        import { mkdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
        import { join } from "node:path";

        export default function (pi) {
          const directory = process.env.JUSTSESSIONS_LIVE_SESSION_REPORTS;
          if (!directory) return;
          const reportFile = join(directory, `${process.pid}.json`);

          pi.on("session_start", (_event, ctx) => {
            try {
              const report = {
                pid: process.pid,
                sessionId: ctx.sessionManager.getSessionId(),
                sessionFile: ctx.sessionManager.getSessionFile() ?? null,
              };
              mkdirSync(directory, { recursive: true });
              writeFileSync(`${reportFile}.partial`, JSON.stringify(report));
              renameSync(`${reportFile}.partial`, reportFile);
            } catch {}
          });

          pi.on("session_shutdown", (event) => {
            if (event.reason !== "quit") return;
            try {
              rmSync(reportFile, { force: true });
            } catch {}
          });
        }

        """#
}
