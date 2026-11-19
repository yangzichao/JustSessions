import Foundation

enum OpenCodeRemoteDatabaseLocation {
    static let shellAssignment = """
        case "${OPENCODE_DB:-}" in
          /*) db=$OPENCODE_DB ;;
          *) case "${XDG_DATA_HOME:-}" in
               /*) db=$XDG_DATA_HOME/opencode/opencode.db ;;
               *) db=$HOME/.local/share/opencode/opencode.db ;;
             esac ;;
        esac
        """
}
