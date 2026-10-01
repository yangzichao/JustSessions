import Foundation

enum KiroTranscriptSamples {
    static let lines = [
        #"{"version":"v1","kind":"Prompt","data":{"content":[{"kind":"text","data":"Fix the build"}],"meta":{"timestamp":1790244000}}}"#,
        #"{"version":"v1","kind":"SystemPrompt","data":{"content":[{"kind":"text","data":"Private instructions"}]}}"#,
        #"{"version":"v1","kind":"AssistantMessage","data":{"content":[{"kind":"thinking","data":"Hidden reasoning"},{"kind":"text","data":"Looking at it."},{"kind":"toolUse","data":{"toolUseId":"t1","name":"shell","input":{"command":"swift build"}}}]}}"#,
        #"{"version":"v1","kind":"ToolResults","data":{"content":[{"kind":"toolResult","data":{"toolUseId":"t1","content":[{"kind":"text","data":"Large tool output"}]}}]}}"#,
        #"{"version":"v1","kind":"AssistantMessage","data":{"content":[{"kind":"toolUse","data":{"toolUseId":"t2","name":"read","input":{"path":"/tmp/Package.swift"}}}]}}"#,
        #"{"version":"v1","kind":"AssistantMessage","data":{"content":[{"kind":"text","data":"Fixed. Café ☕️ 修好了"}]}}"#,
        #"{"version":"v1","kind":"Prompt","data":{"content":[{"kind":"text","data":"Thanks"}]}}"#,
    ]
}
