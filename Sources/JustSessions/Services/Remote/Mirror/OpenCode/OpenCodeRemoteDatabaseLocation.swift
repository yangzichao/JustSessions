import Foundation

enum OpenCodeRemoteDatabaseLocation {
    static func shellAssignment(to variable: String) -> String {
        """
        case "${OPENCODE_DB:-}" in
          /*) \(variable)=$OPENCODE_DB ;;
          *) case "${XDG_DATA_HOME:-}" in
               /*) \(variable)=$XDG_DATA_HOME/opencode/opencode.db ;;
               *) \(variable)=$HOME/.local/share/opencode/opencode.db ;;
             esac ;;
        esac
        """
    }
}
