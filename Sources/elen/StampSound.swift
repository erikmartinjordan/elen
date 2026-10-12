import AVFoundation
import AppKit

/// Sonido corto tipo "golpe de sello" sintetizado al vuelo.
final class StampSound {
    static let shared = StampSound()
    private var player: AVAudioPlayer?

    private init() {
        if let data = Self.makeThudWAV() {
            player = try? AVAudioPlayer(data: data)
            player?.volume = 0.7
            player?.prepareToPlay()
        }
    }

    func play() {
        if let player {
            player.currentTime = 0
            player.play()
        } else {
            NSSound(named: "Pop")?.play()
        }
    }

    private static func makeThudWAV() -> Data? {
        let sampleRate = 44100
        let duration = 0.16
        let frameCount = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            let t = Double(i) / Double(sampleRate)
            let env = exp(-t * 26)
            let freq = 180 - 70 * (t / duration)
            let tone = sin(2 * Double.pi * freq * t)
            let click = exp(-t * 260) * (Double.random(in: -1...1)) * 0.35
            let value = max(-1, min(1, (tone * 0.8 + click) * env))
            samples[i] = Int16(value * 32000)
        }

        var data = Data()
        let dataSize = samples.count * 2
        func append<T: FixedWidthInteger>(_ value: T) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(dataSize))
        for s in samples { append(s) }
        return data
    }
}
