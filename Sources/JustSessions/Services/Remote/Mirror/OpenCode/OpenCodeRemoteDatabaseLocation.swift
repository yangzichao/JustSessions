import Foundation

/// Where OpenCode keeps its database on an SSH host, found as `OpenCodeAdapter.standardDatabaseFile` finds it on
/// this Mac, but from the host's login shell. The mirror and remote deletion both use it, so a session is deleted
/// from the database it was copied from.
enum OpenCodeRemoteDatabaseLocation {
    /// POSIX `sh` that sets `db`.
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
