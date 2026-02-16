import AVFoundation
import SwiftWhisper

public final class WhisperService {
    private var whisper: Whisper?
    private var whisperParams: WhisperParams?

    public init() {
        loadModel()
    }

    private func loadModel() {
        let modelURL: URL? =
            Bundle.module.url(forResource: "ggml-base", withExtension: "bin")
            ?? Bundle.main.url(forResource: "ggml-base", withExtension: "bin")

        guard let url = modelURL else {
            print("[WhisperService] Model file not found in bundle")
            return
        }

        let params = WhisperParams.default
        params.language = .auto
        params.no_context = true
        params.translate = false

        whisperParams = params
        whisper = Whisper(fromFileURL: url, withParams: params)
        print("[WhisperService] Model loaded from \(url.lastPathComponent)")
    }

    public func transcribe(fileURL: URL, translate: Bool = false) async throws -> String {
        guard let whisper else {
            throw WhisperError.modelNotLoaded
        }

        whisperParams?.translate = translate

        let samples = try loadAudioSamples(from: fileURL)

        guard !samples.isEmpty else {
            throw WhisperError.invalidAudioFile
        }

        let segments = try await whisper.transcribe(audioFrames: samples)
        let text = segments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }

    public func transcribe(fileURL: URL, apiKey: String) async throws -> String {
        return try await transcribe(fileURL: fileURL)
    }

    private func loadAudioSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw WhisperError.invalidAudioFile
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw WhisperError.invalidAudioFile
        }

        try file.read(into: buffer)

        guard let channelData = buffer.floatChannelData?[0] else {
            throw WhisperError.invalidAudioFile
        }

        return Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
    }

    public enum WhisperError: Error, LocalizedError {
        case modelNotLoaded
        case invalidAudioFile

        public var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "Whisper model failed to load"
            case .invalidAudioFile: return "Audio file is invalid or too short"
            }
        }
    }
}
