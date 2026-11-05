import AVFoundation
import Combine
import Foundation

struct Recording {
    let samples: [Int16]
    let sampleRate: Int
    let duration: TimeInterval
    let peak: Float

    var isSilent: Bool { peak < 0.01 }
    var wav: Data { WAVEncoder.encode(samples: samples, sampleRate: sampleRate) }
}

/// Cattura il microfono con AVAudioEngine e converte a 16 kHz mono Int16 in memoria.
final class AudioRecorder: ObservableObject {
    /// Livello RMS normalizzato 0...1, aggiornato sul main thread per la pill.
    @Published private(set) var level: Float = 0

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true)!
    private var samples: [Int16] = []
    private var peak: Float = 0
    private var startDate: Date?
    private let lock = NSLock()
    private(set) var isRecording = false

    func start() throws {
        guard !isRecording else { return }
        lock.lock(); samples.removeAll(keepingCapacity: true); peak = 0; lock.unlock()

        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard inFormat.sampleRate > 0, inFormat.channelCount > 0 else { throw WhispError.noAudio }
        guard let conv = AVAudioConverter(from: inFormat, to: targetFormat) else { throw WhispError.noAudio }
        converter = conv

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        engine.prepare()
        try engine.start()
        startDate = Date()
        isRecording = true
        Log.audio.info("Recording started (\(inFormat.sampleRate, privacy: .public) Hz, \(inFormat.channelCount, privacy: .public) ch)")
    }

    func stop() -> Recording {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        let duration = startDate.map { Date().timeIntervalSince($0) } ?? 0
        lock.lock()
        let captured = samples
        let p = peak
        lock.unlock()
        DispatchQueue.main.async { self.level = 0 }
        Log.audio.info("Recording stopped: \(captured.count, privacy: .public) samples, \(duration, privacy: .public)s")
        return Recording(samples: captured, sampleRate: 16_000, duration: duration, peak: p)
    }

    func cancel() {
        _ = stop()
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let channel = out.int16ChannelData else { return }

        let count = Int(out.frameLength)
        guard count > 0 else { return }
        let ptr = UnsafeBufferPointer(start: channel[0], count: count)

        var sumSq: Float = 0
        var localPeak: Float = 0
        for s in ptr {
            let f = Float(s) / 32768
            sumSq += f * f
            localPeak = max(localPeak, abs(f))
        }
        let rms = (sumSq / Float(count)).squareRoot()

        lock.lock()
        samples.append(contentsOf: ptr)
        peak = max(peak, localPeak)
        lock.unlock()

        let lvl = min(1, rms * 6)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // smoothing leggero per un'animazione piu' morbida
            self.level = self.level * 0.4 + lvl * 0.6
        }
    }
}
