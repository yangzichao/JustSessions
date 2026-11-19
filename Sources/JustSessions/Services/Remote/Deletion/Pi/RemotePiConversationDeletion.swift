import Foundation

enum RemotePiConversationDeletion {
    static func hostFileNames(
        of conversation: Conversation,
        piMirrorDirectory: URL
    ) throws -> (folder: RemotePiSessionFolder, fileName: String) {
        let sourceFile = conversation.sourceFile.standardizedFileURL
        let projectFolder = sourceFile.deletingLastPathComponent()
        let mirrorPath = piMirrorDirectory.standardizedFileURL.resolvingSymlinksInPath().path
        let isInRoot = projectFolder.resolvingSymlinksInPath().path == mirrorPath
        guard conversation.provider == .pi,
            conversation.provider.isValidSessionID(conversation.sessionID),
            isInRoot
                || (projectFolder.deletingLastPathComponent().resolvingSymlinksInPath().path == mirrorPath
                    && RemoteConversationDeletion.isSafeFolderName(projectFolder.lastPathComponent)),
            RemoteConversationDeletion.isSafeFolderName(sourceFile.lastPathComponent),
            sourceFile.lastPathComponent.hasSuffix("_\(conversation.sessionID).jsonl")
        else { throw ConversationDeletionError.invalidSource }
        return (isInRoot ? .sessionsRoot : .project(projectFolder.lastPathComponent), sourceFile.lastPathComponent)
    }

    /// The header is checked as text, not parsed: Pi writes it as flat, compact JSON whose first key is `type`.
    static func command(sessionsFolder: String, folder: RemotePiSessionFolder, fileName: String, sessionID: String) -> String {
        let script = #"""
            project=$1 file=$2 id=$3
            case $4 in
              /*) sessions=$4 ;;
              *) sessions="$HOME/$4" ;;
            esac
            case $file in
              ''|.|..|*/*) echo 'Refusing an unexpected session path.' >&2; exit 1 ;;
            esac
            case $project in
              '') dir=$sessions ;;
              .|..|*/*) echo 'Refusing an unexpected session path.' >&2; exit 1 ;;
              *) dir="$sessions/$project"
                 if [ -L "$dir" ]; then echo 'The project folder is a symbolic link.' >&2; exit 1; fi ;;
            esac
            case $file in
              *_"$id".jsonl) ;;
              *) echo 'The file name does not match the session.' >&2; exit 1 ;;
            esac
            path="$dir/$file"
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
            + [folder.projectFolderArgument, fileName, sessionID, sessionsFolder].map(ShellQuoting.quoted).joined(separator: " ")
    }
}
