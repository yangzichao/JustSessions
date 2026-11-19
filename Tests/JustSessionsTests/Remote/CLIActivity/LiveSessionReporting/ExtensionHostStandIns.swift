import Foundation

enum ExtensionHostStandIns {
    static var installedNodePath: String? {
        ["/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"].first(where: FileManager.default.isExecutableFile(atPath:))
    }

    static let stepsFileName = "cli-steps"

    static let pi = #"""
        import { copyFileSync, readFileSync } from "node:fs";
        import { join } from "node:path";
        import { pathToFileURL } from "node:url";

        // Copied to a name that tells node it is a module, as Pi needs no such name.
        const extensionFile = join(process.env.HOME, "extension.mjs");
        copyFileSync(process.argv[process.argv.indexOf("--extension") + 1], extensionFile);
        const { default: extension } = await import(pathToFileURL(extensionFile).href);
        const handlers = {};
        extension({ on: (name, handler) => { handlers[name] = handler; }, registerEntryRenderer() {} });
        const context = { sessionManager: { getSessionId: () => "abc", getSessionFile: () => undefined }, isIdle: () => true };
        handlers.session_start({}, context);

        let stepsRun = 0;
        setInterval(() => {
          let steps = [];
          try { steps = readFileSync(join(process.env.HOME, "\#(stepsFileName)"), "utf8").split("\n").filter(Boolean); } catch {}
          for (const step of steps.slice(stepsRun)) {
            const [name, title] = step.split("\t");
            handlers[name]?.({ kind: "confirm", title, reason: "quit" }, context);
          }
          stepsRun = steps.length;
        }, 100);
        """#

    /// `opencode` with `OPENCODE_TUI_CONFIG`, whose plugin it loads as OpenCode does. A step is the TUI's state as JSON:
    /// `session`, the session on screen or null, `status`, and `permissions`, how many are open.
    static let openCode = #"""
        import { copyFileSync, readFileSync } from "node:fs";
        import { dirname, join, resolve } from "node:path";
        import { pathToFileURL } from "node:url";

        const configuration = process.env.OPENCODE_TUI_CONFIG;
        // Copied to a name that tells node it is a module, as OpenCode needs no such name.
        const pluginFile = join(process.env.HOME, "plugin.mjs");
        copyFileSync(resolve(dirname(configuration), JSON.parse(readFileSync(configuration, "utf8")).plugin[0]), pluginFile);
        const { default: plugin } = await import(pathToFileURL(pluginFile).href);
        let state = { session: null, status: "idle", permissions: 0 };
        await plugin.tui({
          route: { get current() { return state.session ? { name: "session", params: { sessionID: state.session } } : { name: "home" }; } },
          state: {
            session: {
              get: () => ({}),
              status: () => ({ type: state.status }),
              permission: () => Array(state.permissions).fill({}),
              question: () => [],
            },
          },
          event: { on: () => () => {} },
          lifecycle: { onDispose: () => {} },
        });

        setInterval(() => {
          let steps = [];
          try { steps = readFileSync(join(process.env.HOME, "\#(stepsFileName)"), "utf8").split("\n").filter(Boolean); } catch {}
          if (steps.length > 0) state = JSON.parse(steps.at(-1));
        }, 100);
        """#
}
