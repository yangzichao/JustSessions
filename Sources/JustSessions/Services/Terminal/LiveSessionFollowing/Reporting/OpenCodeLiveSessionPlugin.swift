import Foundation

/// The OpenCode TUI plugin that reports the session an OpenCode CLI shows; see `LiveSessionReporting`. OpenCode loads
/// it from the TUI configuration that `OPENCODE_TUI_CONFIG` names, on top of the user's own `tui.json` files. The
/// plugin API has no event for a change of screen, so the plugin checks the screen twice a second.
enum OpenCodeLiveSessionPlugin {
    static let fileName = "justsessions-live-session.js"
    static let tuiConfigurationVariable = "OPENCODE_TUI_CONFIG"

    static func tuiConfiguration(loading pluginFile: URL) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: ["plugin": [pluginFile.path]],
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return nil }
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    static let source = #"""
        // JustSessions starts OpenCode with this TUI plugin and rewrites this file when the app changes it. It tells the
        // app which session this OpenCode shows, so the app's tab follows /new and the sessions you open.
        import { mkdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
        import { join } from "node:path";

        export default {
          id: "justsessions-live-session",
          tui: async (api) => {
            const directory = process.env.JUSTSESSIONS_LIVE_SESSION_REPORTS;
            if (!directory) return;
            const reportFile = join(directory, `${process.pid}.json`);
            let reportedSessionId;

            const report = () => {
              const route = api.route.current;
              const sessionId = route.name === "session" ? route.params?.sessionID ?? null : null;
              if (sessionId === reportedSessionId) return;
              try {
                mkdirSync(directory, { recursive: true });
                writeFileSync(`${reportFile}.partial`, JSON.stringify({ pid: process.pid, sessionId }));
                renameSync(`${reportFile}.partial`, reportFile);
                reportedSessionId = sessionId;
              } catch {}
            };

            report();
            const timer = setInterval(report, 500);
            timer.unref?.();
            api.lifecycle.onDispose(() => {
              clearInterval(timer);
              try {
                rmSync(reportFile, { force: true });
              } catch {}
            });
          },
        };

        """#
}
