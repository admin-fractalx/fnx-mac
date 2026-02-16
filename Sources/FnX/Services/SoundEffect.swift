import AVFoundation

public final class SoundEffect {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    public init() {}

    /// Short ascending two-tone chirp — "recording started"
    public func playStartTone() {
        playTones(frequencies: [880, 1175], duration: 0.06, pause: 0.04, volume: 0.15)
    }

    /// Short descending tone — "recording stopped"
    public func playStopTone() {
        playTones(frequencies: [1175, 880], duration: 0.06, pause: 0.04, volume: 0.15)
    }

    /// Gentle success chime
    public func playDoneTone() {
        playTones(frequencies: [784, 1047], duration: 0.08, pause: 0.05, volume: 0.12)
    }

    private func playTones(frequencies: [Double], duration: Double, pause: Double, volume: Float) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.generateAndPlay(frequencies: frequencies, duration: duration, pause: pause, volume: volume)
        }
    }

    private func generateAndPlay(frequencies: [Double], duration: Double, pause: Double, volume: Float) {
        let sampleRate: Double = 44100
        let samplesPerTone = Int(duration * sampleRate)
        let pauseSamples = Int(pause * sampleRate)
        let totalSamples = frequencies.count * samplesPerTone + (frequencies.count - 1) * pauseSamples
        let fadeLength = min(80, samplesPerTone / 4)

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples))
        else { return }

        buffer.frameLength = AVAudioFrameCount(totalSamples)
        guard let data = buffer.floatChannelData?[0] else { return }

        var offset = 0
        for (index, freq) in frequencies.enumerated() {
            for i in 0..<samplesPerTone {
                let sample = sin(2.0 * .pi * freq * Double(i) / sampleRate)

                // Smooth fade in/out to avoid clicks
                var envelope: Double = 1.0
                if i < fadeLength {
                    envelope = Double(i) / Double(fadeLength)
                } else if i > samplesPerTone - fadeLength {
                    envelope = Double(samplesPerTone - i) / Double(fadeLength)
                }

                data[offset + i] = Float(sample * envelope * Double(volume))
            }
            offset += samplesPerTone

            // Add silence between tones
            if index < frequencies.count - 1 {
                for i in 0..<pauseSamples {
                    data[offset + i] = 0
                }
                offset += pauseSamples
            }
        }

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            player.play()
            player.scheduleBuffer(buffer) {
                DispatchQueue.global().async {
                    engine.stop()
                }
            }
        } catch {
            // Silently fail — sound is not critical
        }
    }
}
