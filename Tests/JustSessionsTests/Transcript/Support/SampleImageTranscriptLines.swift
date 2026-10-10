import Foundation
@testable import JustSessions

/// Session files with a user's image and a tool's image, each followed by text, as the CLIs write them.
enum SampleImageTranscriptLines {
    static let claude = [
        #"{"type":"user","timestamp":"2026-09-24T10:00:00.000Z","message":{"role":"user","content":[{"type":"text","text":"What is in this screenshot?"},{"type":"image","source":{"type":"base64","media_type":"image/png","data":"\#(SampleTranscriptImage.base64)"}}]}}"#,
        #"{"type":"assistant","timestamp":"2026-09-24T10:00:01.000Z","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/red.png"}}]}}"#,
        #"{"type":"user","timestamp":"2026-09-24T10:00:02.000Z","message":{"role":"user","content":[{"type":"tool_result","content":[{"type":"text","text":"hidden caption"},{"type":"image","source":{"type":"base64","media_type":"image/png","data":"\#(SampleTranscriptImage.base64)"}}]}]}}"#,
        #"{"type":"assistant","timestamp":"2026-09-24T10:00:03.000Z","message":{"role":"assistant","content":"A red rectangle."}}"#,
    ]

    static let codex = [
        #"{"timestamp":"2026-09-24T10:00:00.000Z","type":"session_meta","payload":{"id":"abc","cwd":"/tmp"}}"#,
        #"{"timestamp":"2026-09-24T10:00:01.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"What is in this screenshot?"},{"type":"input_image","image_url":"data:image/png;base64,\#(SampleTranscriptImage.base64)"}]}}"#,
        #"{"timestamp":"2026-09-24T10:00:02.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"A red rectangle."}]}}"#,
    ]

    static let pi = [
        #"{"type":"session","version":3,"id":"019a0000-0000-7000-8000-000000000000","timestamp":"2026-09-24T10:00:00.000Z","cwd":"/tmp"}"#,
        #"{"type":"message","id":"a1","parentId":null,"timestamp":"2026-09-24T10:00:01.000Z","message":{"role":"user","content":[{"type":"text","text":"What is in this screenshot?"},{"type":"image","data":"\#(SampleTranscriptImage.base64)","mimeType":"image/png"}],"timestamp":1}}"#,
        #"{"type":"message","id":"a2","parentId":"a1","timestamp":"2026-09-24T10:00:02.000Z","message":{"role":"assistant","content":[{"type":"toolCall","id":"t1","name":"screenshot","arguments":{}}],"stopReason":"toolUse","timestamp":2}}"#,
        #"{"type":"message","id":"a3","parentId":"a2","timestamp":"2026-09-24T10:00:03.000Z","message":{"role":"toolResult","toolCallId":"t1","toolName":"screenshot","content":[{"type":"image","data":"\#(SampleTranscriptImage.base64)","mimeType":"image/png"}],"isError":false,"timestamp":3}}"#,
        #"{"type":"message","id":"a4","parentId":"a3","timestamp":"2026-09-24T10:00:04.000Z","message":{"role":"assistant","content":[{"type":"text","text":"A red rectangle."}],"stopReason":"stop","timestamp":4}}"#,
    ]
}
