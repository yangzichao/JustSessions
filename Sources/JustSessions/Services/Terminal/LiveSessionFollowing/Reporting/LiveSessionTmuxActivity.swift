import Foundation

enum LiveSessionTmuxActivity {
    static let optionVariable = "JUSTSESSIONS_TMUX_ACTIVITY_OPTION"

    static let importTheJavascriptNeeds = #"import { execFile } from "node:child_process";"#

    static let javascript = #"""
        // On an SSH host, the app reads what this CLI does from the title tmux gives its tab, which shows this option.
        const showInTmux = (() => {
          const option = process.env.\#(optionVariable);
          const pane = process.env.TMUX_PANE;
          if (!option || !pane) return undefined;
          let shown;
          let wanted = "";
          let isSetting = false;
          const setWanted = () => {
            if (wanted === shown) {
              isSetting = false;
              return;
            }
            isSetting = true;
            const value = wanted;
            // tmux reads an argument that ends in ";" as the end of its command.
            const argument = value.endsWith(";") ? `${value.slice(0, -1)}\\;` : value;
            const command = ["set-option", "-wq", "-t", pane, option, argument, ";", "refresh-client", "-S"];
            execFile("tmux", command, { timeout: 5000 }, () => {
              shown = value;
              setWanted();
            });
          };
          return (activity, waitingFor) => {
            const reason = (waitingFor ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").slice(0, 200);
            wanted = activity ? `${activity}:${reason}` : "";
            if (!isSetting) setWanted();
          };
        })();
        """#
}
