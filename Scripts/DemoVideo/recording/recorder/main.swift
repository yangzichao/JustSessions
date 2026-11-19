import AVFoundation
// stage-recorder <output.mov> <seconds>: records only the demo app's windows inside the stage rectangle
// (DEMO_STAGE, in points), over a solid background, at 2x and 60 fps. Stops early when <output>.stop exists.
import AppKit
import Foundation
import ScreenCaptureKit

let environment = ProcessInfo.processInfo.environment
let stage: CGRect = {
    let values = (environment["DEMO_STAGE"] ?? "").split(separator: " ").compactMap { Double($0) }
    guard values.count == 4, environment["DEMO_APP_EXECUTABLE"] != nil
    else { fatalError("Run this through Scripts/DemoVideo/demo-video, which sets DEMO_STAGE and DEMO_APP_EXECUTABLE.") }
    return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
}()
let backgroundColor = CGColor(srgbRed: 0x15 / 255.0, green: 0x17 / 255.0, blue: 0x1c / 255.0, alpha: 1)

final class RecordingDelegate: NSObject, SCRecordingOutputDelegate {
    var finished = false
    func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        print(String(format: "RECORDING STARTED %.3f", Date().timeIntervalSince1970))
        fflush(stdout)
    }
    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        print("RECORDING FAILED: \(error)")
        fflush(stdout)
        finished = true
    }
    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        print(String(format: "RECORDING FINISHED %.3f", Date().timeIntervalSince1970))
        fflush(stdout)
        finished = true
    }
}

func demoProcessIdentifier() -> pid_t? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-f", environment["DEMO_APP_EXECUTABLE"]!]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    process.waitUntilExit()
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return output.split(separator: "\n").first.flatMap { pid_t($0) }
}

@main struct StageRecorder {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let seconds = Double(CommandLine.arguments[2])!
        guard let processIdentifier = demoProcessIdentifier() else { fatalError("demo app is not running") }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        guard let application = content.applications.first(where: { $0.processID == processIdentifier }),
            let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() })
        else { fatalError("demo app or main display not found") }
        let filter = SCContentFilter(display: display, including: [application], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = stage
        configuration.width = Int(stage.width) * 2
        configuration.height = Int(stage.height) * 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 8
        configuration.showsCursor = true
        configuration.backgroundColor = backgroundColor
        configuration.capturesAudio = false
        configuration.captureMicrophone = false
        configuration.colorSpaceName = CGColorSpace.sRGB
        let recordingConfiguration = SCRecordingOutputConfiguration()
        recordingConfiguration.outputURL = outputURL
        recordingConfiguration.outputFileType = .mov
        recordingConfiguration.videoCodecType = .hevc
        let delegate = RecordingDelegate()
        let recording = SCRecordingOutput(configuration: recordingConfiguration, delegate: delegate)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addRecordingOutput(recording)
        try await stream.startCapture()
        let stopFile = outputURL.appendingPathExtension("stop")
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline && !FileManager.default.fileExists(atPath: stopFile.path) {
            try await Task.sleep(for: .milliseconds(50))
        }
        try await stream.stopCapture()
        for _ in 0..<200 where !delegate.finished { try await Task.sleep(for: .milliseconds(50)) }
    }
}
