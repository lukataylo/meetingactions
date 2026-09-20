import AVFoundation
import Combine

// Captures the default input to numbered wav segments and publishes a level
// history for the waveform. A device change (Teams mute/unmute re-opens the
// mic) or 5s of silence from the engine starts a fresh segment instead of
// silently losing the rest of the call; piroba.sh concatenates them.
final class Recorder: ObservableObject {
    @Published var levels: [Float] = Array(repeating: 0, count: 20)
    @Published var elapsed: TimeInterval = 0
    @Published private(set) var isRecording = false
    private(set) var dir: URL?
    var deviceUID = ""   // "" = system default input

    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var segment = 0
    private var startedAt = Date()
    private var lastBuffer = Date()
    private var timer: Timer?

    func start(into dir: URL) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.dir = dir
        segment = 0
        startedAt = Date()
        NotificationCenter.default.addObserver(self, selector: #selector(configChanged),
                                               name: .AVAudioEngineConfigurationChange, object: engine)
        try openSegment()
        isRecording = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
    }

    @discardableResult
    func stop() -> URL? {
        timer?.invalidate(); timer = nil
        closeSegment()
        NotificationCenter.default.removeObserver(self)
        isRecording = false
        levels = Array(repeating: 0, count: levels.count)
        elapsed = 0
        defer { dir = nil }
        return dir
    }

    private func openSegment() throws {
        guard let dir else { return }
        segment += 1
        let input = engine.inputNode
        if let id = deviceUID.isEmpty ? nil : AudioDevices.id(forUID: deviceUID), let unit = input.audioUnit {
            var dev = id
            AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
                                 &dev, UInt32(MemoryLayout<AudioDeviceID>.size))
        }
        let fmt = input.outputFormat(forBus: 0)
        let url = dir.appendingPathComponent(String(format: "audio-%02d.wav", segment))
        // ponytail: native sample rate, whisper resamples anyway
        file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: fmt.sampleRate,
            AVNumberOfChannelsKey: fmt.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ], commonFormat: fmt.commonFormat, interleaved: fmt.isInterleaved)
        input.installTap(onBus: 0, bufferSize: 4096, format: fmt) { [weak self] buf, _ in self?.consume(buf) }
        engine.prepare()
        try engine.start()
        lastBuffer = Date()
    }

    private func closeSegment() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
    }

    private func consume(_ buf: AVAudioPCMBuffer) {
        try? file?.write(from: buf)   // ponytail: writes on the audio thread, fine for speech
        lastBuffer = Date()
        guard let ch = buf.floatChannelData?[0], buf.frameLength > 0 else { return }
        var sum: Float = 0
        for i in 0..<Int(buf.frameLength) { sum += ch[i] * ch[i] }
        let rms = (sum / Float(buf.frameLength)).squareRoot()
        let level = min(1, rms * 6)   // ponytail: gain knob — raise if bars sit flat for quiet talkers
        DispatchQueue.main.async {
            self.levels.removeFirst()
            self.levels.append(level)
        }
    }

    @objc private func configChanged() { DispatchQueue.main.async { self.restartSegment() } }

    private func tick() {
        elapsed = Date().timeIntervalSince(startedAt)
        if Date().timeIntervalSince(lastBuffer) > 5 { restartSegment() }
    }

    private func restartSegment() {
        guard isRecording else { return }
        closeSegment()
        try? openSegment()
    }
}
