import Foundation

/// The OpenCode TUI plugin that reports the session an OpenCode CLI shows, and what it is doing; see
/// `LiveSessionReporting`. OpenCode loads it from the TUI configuration that `OPENCODE_TUI_CONFIG` names, on top of the
/// user's own `tui.json` files. The plugin API has no event for a change of screen, so the plugin checks the screen
/// twice a second.
///
/// `activity` is "waiting" while a permission or question of the session, or of a subagent it started, waits on you,
/// with `waitingFor` saying which; "working" while OpenCode's status for the session is busy or retrying; and "idle"
/// otherwise. The plugin reads these from the TUI's own state, as the TUI shows them. A subagent's session on screen
/// reports the activity of the top-level session that started it, the one the app lists.
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
        // app which session this OpenCode shows, so the app's tab follows /new and the sessions you open, and whether
        // OpenCode is working, waiting on you, or done with its turn.
        import { mkdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
        import { join } from "node:path";

        export default {
          id: "justsessions-live-session",
          tui: async (api) => {
            const directory = process.env.JUSTSESSIONS_LIVE_SESSION_REPORTS;
            if (!directory) return;
            const reportFile = join(directory, `${process.pid}.json`);
            const reportsActivity = typeof api.event?.on === "function"
              && ["get", "status", "permission", "question"].every((name) => typeof api.state?.session?.[name] === "function");
            // Sessions that asked for a permission or an answer while the plugin ran; a subagent's asks in its own.
            const askingSessionIds = new Set();
            let reportedJSON;

            const topLevelSessionId = (sessionId) => {
              let id = sessionId;
              for (let depth = 0; depth < 16; depth += 1) {
                const parentId = api.state.session.get(id)?.parentID;
                if (!parentId) return id;
                id = parentId;
              }
              return id;
            };

            const activity = (sessionId) => {
              for (const id of [sessionId, ...askingSessionIds]) {
                if (id !== sessionId && topLevelSessionId(id) !== sessionId) continue;
                if (api.state.session.permission(id).length > 0) return { activity: "waiting", waitingFor: "permission" };
                if (api.state.session.question(id).length > 0) return { activity: "waiting", waitingFor: "question" };
              }
              const status = api.state.session.status(sessionId)?.type;
              return { activity: status === "busy" || status === "retry" ? "working" : "idle" };
            };

            const report = () => {
              const route = api.route.current;
              const sessionId = route.name === "session" ? route.params?.sessionID ?? null : null;
              const json = JSON.stringify({
                pid: process.pid,
                sessionId,
                ...(sessionId && reportsActivity ? activity(topLevelSessionId(sessionId)) : {}),
              });
              if (json === reportedJSON) return;
              try {
                mkdirSync(directory, { recursive: true });
                writeFileSync(`${reportFile}.partial`, json);
                renameSync(`${reportFile}.partial`, reportFile);
                reportedJSON = json;
              } catch {}
            };

            const unsubscribers = [];
            if (reportsActivity) {
              for (const askedEvent of ["permission.asked", "question.asked"]) {
                unsubscribers.push(api.event.on(askedEvent, (event) => {
                  askingSessionIds.add(event.properties.sessionID);
                  report();
                }));
              }
              for (const changeEvent of ["permission.replied", "question.replied", "question.rejected", "session.status"]) {
                unsubscribers.push(api.event.on(changeEvent, report));
              }
            }

            report();
            const timer = setInterval(report, 500);
            timer.unref?.();
            api.lifecycle.onDispose(() => {
              clearInterval(timer);
              for (const unsubscribe of unsubscribers) unsubscribe?.();
              try {
                rmSync(reportFile, { force: true });
              } catch {}
            });
          },
        };

        """#
}
