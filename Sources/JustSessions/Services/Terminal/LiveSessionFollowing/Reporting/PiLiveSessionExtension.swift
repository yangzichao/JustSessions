import Foundation

/// The Pi extension that reports the session a Pi CLI is in, and what the CLI is doing; see `LiveSessionReporting`.
/// Pi starts its extensions' `session_start` handlers when it starts, reloads, and with `/new`, `/resume`, `/fork`,
/// and `/clone`, each time with the session it then shows. Pi 0.65 and later report the session.
///
/// Pi 0.80.4 and later also report `activity`: "working" from `agent_start` until `agent_settled`, after which Pi
/// runs nothing more on its own, and "idle" otherwise. From Pi 0.84.4 it is "waiting" while a run waits on a prompt
/// an extension shows, such as a permission gate, with the prompt's title as `waitingFor`; Pi itself asks no
/// permission for tool calls. Earlier versions never fire `agent_settled`, so the extension leaves `activity` out
/// rather than report a run that never ends.
enum PiLiveSessionExtension {
    static let fileName = "justsessions-live-session.js"

    static let source = #"""
        // JustSessions starts Pi with this extension and rewrites this file when the app changes it. It tells the app
        // which session this Pi is in, so the app's tab follows /new, /resume, /fork, and /clone, and whether Pi is
        // working, waiting on you, or done with its turn.
        import { mkdirSync, renameSync, rmSync, writeFileSync } from "node:fs";
        import { join } from "node:path";

        export default function (pi) {
          const directory = process.env.JUSTSESSIONS_LIVE_SESSION_REPORTS;
          if (!directory) return;
          const reportFile = join(directory, `${process.pid}.json`);
          // Pi 0.80.4 added agent_settled together with registerEntryRenderer.
          const reportsActivity = typeof pi.registerEntryRenderer === "function";
          let session;
          let isRunning = false;
          const openPrompts = [];

          const write = () => {
            if (!session) return;
            const report = { pid: process.pid, ...session };
            if (reportsActivity) {
              const waitingPrompt = isRunning ? openPrompts.at(-1) : undefined;
              report.activity = waitingPrompt ? "waiting" : isRunning ? "working" : "idle";
              if (waitingPrompt?.title) report.waitingFor = waitingPrompt.title;
            }
            try {
              mkdirSync(directory, { recursive: true });
              writeFileSync(`${reportFile}.partial`, JSON.stringify(report));
              renameSync(`${reportFile}.partial`, reportFile);
            } catch {}
          };

          pi.on("session_start", (_event, ctx) => {
            session = {
              sessionId: ctx.sessionManager.getSessionId(),
              sessionFile: ctx.sessionManager.getSessionFile() ?? null,
            };
            isRunning = typeof ctx.isIdle === "function" ? !ctx.isIdle() : false;
            openPrompts.length = 0;
            write();
          });

          pi.on("agent_start", () => {
            isRunning = true;
            write();
          });

          pi.on("agent_settled", () => {
            isRunning = false;
            openPrompts.length = 0;
            write();
          });

          pi.on("ui_prompt_start", (event) => {
            openPrompts.push({ kind: event.kind, title: event.title });
            write();
          });

          pi.on("ui_prompt_end", (event) => {
            const index = openPrompts.findLastIndex((prompt) => prompt.kind === event.kind && prompt.title === event.title);
            openPrompts.splice(index >= 0 ? index : openPrompts.length - 1, 1);
            write();
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
