import Foundation

/// Deletes a Pi session in the host's sessions folder, the one the mirror copied from: the folder of the same name
/// beside its `.jsonl` file, where extensions keep subagent runs and forks, then the file.
enum RemotePiConversationDeletion {
    /// The project folder and file names of a mirrored session, which name the same file on the host. Only a file
    /// directly in a project folder of the host's Pi mirror, named for the session, is accepted.
    static func hostFileNames(
        of conversation: Conversation,
        piMirrorDirectory: URL
    ) throws -> (projectFolderName: String, fileName: String) {
        let sourceFile = conversation.sourceFile.standardizedFileURL
        let projectFolder = sourceFile.deletingLastPathComponent()
        let mirrorPath = piMirrorDirectory.standardizedFileURL.resolvingSymlinksInPath().path
        guard conversation.provider == .pi,
              conversation.provider.isValidSessionID(conversation.sessionID),
              projectFolder.deletingLastPathComponent().resolvingSymlinksInPath().path == mirrorPath,
              RemoteConversationDeletion.isSafeFolderName(projectFolder.lastPathComponent),
              RemoteConversationDeletion.isSafeFolderName(sourceFile.lastPathComponent),
              sourceFile.lastPathComponent.hasSuffix("_\(conversation.sessionID).jsonl")
        else { throw ConversationDeletionError.invalidSource }
        return (projectFolder.lastPathComponent, sourceFile.lastPathComponent)
    }

    /// A POSIX `sh` script that takes the names and id as arguments, so none of them is ever read as shell code.
    /// It refuses a project folder or session file that is a symbolic link, anything but a regular file, and a file
    /// whose first line is not that session's header. A symbolically linked folder beside the session is left in place.
    /// The folder goes first, so if removing the file then fails the session is still listed.
    ///
    /// The header is checked as text, not parsed: Pi writes it as flat, compact JSON whose first key is `type`.
    ///
    /// `sessionsFolder` is absolute, or relative to the host's home; see `RemoteToolFolders`.
    static func command(sessionsFolder: String, projectFolderName: String, fileName: String, sessionID: String) -> String {
        let script = #"""
            project=$1 file=$2 id=$3
            case $4 in
              /*) sessions=$4 ;;
              *) sessions="$HOME/$4" ;;
            esac
            for name in "$project" "$file"; do
              case $name in
                ''|.|..|*/*) echo 'Refusing an unexpected session path.' >&2; exit 1 ;;
              esac
            done
            case $file in
              *_"$id".jsonl) ;;
              *) echo 'The file name does not match the session.' >&2; exit 1 ;;
            esac
            dir="$sessions/$project"
            path="$dir/$file"
            if [ -L "$dir" ]; then echo 'The project folder is a symbolic link.' >&2; exit 1; fi
            [ -e "$path" ] || [ -L "$path" ] || exit \#(RemoteConversationDeletion.missingTranscriptExitStatus)
            if [ -L "$path" ] || [ ! -f "$path" ]; then echo 'The session file is not a regular file.' >&2; exit 1; fi
            header=$(head -n 1 "$path") || exit 1
            case $header in
              '{"type":"session",'*) ;;
              *) echo 'The file is not a Pi session. Refresh before deleting.' >&2; exit 1 ;;
            esac
            case $header in
              *'"id":"'"$id"'"'*) ;;
              *) echo 'The file belongs to another session. Refresh before deleting.' >&2; exit 1 ;;
            esac
            folder="${path%.jsonl}"
            if [ -d "$folder" ] && [ ! -L "$folder" ]; then
              rm -rf "$folder" || exit 1
            fi
            rm -f "$path" || exit 1
            """#
        return "sh -c \(ShellQuoting.quoted(script)) sh "
            + [projectFolderName, fileName, sessionID, sessionsFolder].map(ShellQuoting.quoted).joined(separator: " ")
    }
}
